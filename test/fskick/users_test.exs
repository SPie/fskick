defmodule Fskick.UsersTest do
  use Fskick.DataCase

  import Ecto.Query, only: [from: 2]
  import Fskick.UsersFixtures

  alias Fskick.Players
  alias Fskick.Players.Events.PlayerRenamed
  alias Fskick.Users
  alias Fskick.Users.CryptoKey
  alias Fskick.Users.Events.UserEmailChanged
  alias Fskick.Users.Events.UserPasswordChanged
  alias Fskick.Users.Session
  alias Fskick.Users.User

  describe "update_profile/2" do
    setup do
      %{user: user_fixture(%{email: "alice@example.com", player_name: "Alice"})}
    end

    test "changes the email", %{user: user} do
      assert {:ok, %User{email: "new@example.com"}} =
               Users.update_profile(user, profile_params(%{"email" => "New@Example.com"}))

      assert [%UserEmailChanged{email: "new@example.com"}] = change_events(user)
    end

    test "renames the linked player", %{user: user} do
      assert {:ok, %User{}} =
               Users.update_profile(user, profile_params(%{"player_name" => "Bob"}))

      assert Users.get_user(user.id).player.name == "Bob"
      assert [%PlayerRenamed{name: "Bob"}] = change_events(user)
    end

    test "changes the password", %{user: user} do
      assert {:ok, %User{}} = Users.update_profile(user, profile_params(password_params()))

      assert [%UserPasswordChanged{}] = change_events(user)
      assert Users.get_user_by_email_and_password("alice@example.com", "a new password")
      refute Users.get_user_by_email_and_password("alice@example.com", valid_user_password())
    end

    test "changes everything at once, with separate events", %{user: user} do
      attrs =
        profile_params(
          Map.merge(password_params(), %{"email" => "new@example.com", "player_name" => "Bob"})
        )

      assert {:ok, %User{email: "new@example.com"}} = Users.update_profile(user, attrs)

      assert [%PlayerRenamed{}, %UserEmailChanged{}, %UserPasswordChanged{}] = change_events(user)
    end

    test "writes nothing when nothing changed", %{user: user} do
      attrs = profile_params(%{"email" => " ALICE@example.com", "player_name" => " Alice "})

      assert {:ok, %User{email: "alice@example.com"}} = Users.update_profile(user, attrs)

      assert [] = change_events(user)
    end

    test "applies nothing when any field is invalid", %{user: user} do
      attrs =
        profile_params(%{
          "email" => "new@example.com",
          "player_name" => "Bob",
          "password" => "a new password"
        })

      assert {:error, %Ecto.Changeset{} = changeset} = Users.update_profile(user, attrs)

      assert %{current_password: ["can't be blank"]} = errors_on(changeset)
      assert [] = change_events(user)
      assert Users.get_user(user.id).email == "alice@example.com"
      assert Users.get_user(user.id).player.name == "Alice"
    end

    test "rejects an email and a player name that are taken", %{user: user} do
      user_fixture(%{email: "bob@example.com", player_name: "Bob"})

      attrs = profile_params(%{"email" => "bob@example.com", "player_name" => "Bob"})

      assert {:error, changeset} = Users.update_profile(user, attrs)

      assert %{email: ["has already been taken"], player_name: ["has already been taken"]} =
               errors_on(changeset)
    end

    test "frees the old email and player name", %{user: user} do
      attrs = profile_params(%{"email" => "new@example.com", "player_name" => "Bob"})
      assert {:ok, _user} = Users.update_profile(user, attrs)

      assert %User{} = user_fixture(%{email: "alice@example.com", player_name: "Alice"})
    end

    test "dispatches every command before a failure stops the update" do
      user = streamless_user_fixture(%{email: "carol@example.com", player_name: "Carol"})

      attrs = profile_params(%{"email" => "new@example.com", "player_name" => "Caroline"})

      assert {:error, :not_found} = Users.update_profile(user, attrs)

      # The rename comes first and is stored; the email change has no user
      # stream to land on.
      assert [%PlayerRenamed{name: "Caroline"}] =
               "player-#{user.player_id}"
               |> stream_events()
               |> Enum.filter(&match?(%PlayerRenamed{}, &1))

      assert Users.get_user(user.id).email == "carol@example.com"
    end

    test "diffs against the stored user, not the one passed in", %{user: user} do
      assert {:ok, _user} =
               Users.update_profile(user, profile_params(%{"email" => "new@example.com"}))

      # `user` still says alice@example.com, but that change already landed.
      assert {:ok, _user} =
               Users.update_profile(user, profile_params(%{"email" => "new@example.com"}))

      assert [%UserEmailChanged{}] = change_events(user)
    end

    test "keeps the session when the password changes", %{user: user} do
      {:ok, token} = Users.start_session(user)

      assert {:ok, _user} = Users.update_profile(user, profile_params(password_params()))

      assert %User{} = Users.get_user_by_session_token(token)
    end

    defp profile_params(overrides) do
      Map.merge(
        %{
          "email" => "alice@example.com",
          "player_name" => "Alice",
          "current_password" => "",
          "password" => "",
          "password_confirmation" => ""
        },
        overrides
      )
    end

    defp password_params() do
      %{
        "current_password" => valid_user_password(),
        "password" => "a new password",
        "password_confirmation" => "a new password"
      }
    end

    # The profile events on the player's and the user's streams, in that order.
    defp change_events(%User{id: id, player_id: player_id}) do
      ["player-#{player_id}", "user-#{id}"]
      |> Enum.flat_map(&stream_events/1)
      |> Enum.filter(
        &match?(%mod{} when mod in [PlayerRenamed, UserEmailChanged, UserPasswordChanged], &1)
      )
    end

    defp stream_events(stream_uuid) do
      case Commanded.EventStore.stream_forward(Fskick.App, stream_uuid) do
        {:error, :stream_not_found} -> []
        events -> Enum.map(events, & &1.data)
      end
    end
  end

  describe "register_user_for_player/3" do
    test "registers a user linked to an existing player" do
      player = player_fixture()

      assert {:ok, %User{} = user} =
               Users.register_user_for_player(player.id, "alice@example.com", "hello world!")

      assert user.email == "alice@example.com"
      assert user.player_id == player.id
      assert user.hashed_password != "hello world!"
    end

    test "generates a crypto key for the user" do
      player = player_fixture()
      {:ok, user} = Users.register_user_for_player(player.id, "alice@example.com", "hello world!")

      assert KeyRepo.get(CryptoKey, user.id)
    end

    test "normalizes the email" do
      player = player_fixture()

      assert {:ok, %User{email: "alice@example.com"}} =
               Users.register_user_for_player(player.id, "  Alice@Example.COM  ", "hello world!")
    end

    test "rejects a duplicate email" do
      player = player_fixture()
      {:ok, _} = Users.register_user_for_player(player.id, "alice@example.com", "hello world!")

      other = player_fixture()

      assert {:error, changeset} =
               Users.register_user_for_player(other.id, "alice@example.com", "hello world!")

      assert "has already been taken" in errors_on(changeset).email
    end

    test "rejects an invalid email" do
      player = player_fixture()

      assert {:error, changeset} =
               Users.register_user_for_player(player.id, "not-an-email", "hello world!")

      assert "must be a valid email" in errors_on(changeset).email
    end

    test "rejects an unknown player" do
      assert {:error, changeset} =
               Users.register_user_for_player(Ecto.UUID.generate(), "a@b.co", "hello world!")

      assert "does not exist" in errors_on(changeset).player_id
    end
  end

  describe "register_user_with_new_player/3" do
    test "creates a player and a linked user" do
      assert {:ok, %User{} = user} =
               Users.register_user_with_new_player("Alice", "alice@example.com", "hello world!")

      player = user.player
      assert player.name == "Alice"
      assert player.id == user.player_id
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "returns the user with the correct password" do
      user = user_fixture(%{email: "alice@example.com", password: "hello world!"})

      assert %User{id: id} =
               Users.get_user_by_email_and_password("alice@example.com", "hello world!")

      assert id == user.id
    end

    test "is case-insensitive on the email" do
      user = user_fixture(%{email: "alice@example.com", password: "hello world!"})

      assert %User{id: id} =
               Users.get_user_by_email_and_password("ALICE@example.com", "hello world!")

      assert id == user.id
    end

    test "returns nil for a wrong password" do
      user_fixture(%{email: "alice@example.com", password: "hello world!"})
      refute Users.get_user_by_email_and_password("alice@example.com", "wrong")
    end

    test "returns nil for an unknown email" do
      refute Users.get_user_by_email_and_password("nobody@example.com", "hello world!")
    end
  end

  describe "sessions" do
    test "start, look up, and end a session" do
      user = user_fixture()

      assert {:ok, token} = Users.start_session(user)
      assert %User{id: id} = Users.get_user_by_session_token(token)
      assert id == user.id

      assert :ok = Users.end_session(token)
      refute Users.get_user_by_session_token(token)
    end

    test "the stored row holds a hash, not the token itself" do
      user = user_fixture()
      {:ok, token} = Users.start_session(user)

      session = Repo.one(from s in Session, where: s.user_id == ^user.id)

      refute session.token_hash == token
      assert session.token_hash == :crypto.hash(:sha256, token)
    end

    test "a session expires one day after it starts" do
      user = user_fixture()
      {:ok, _token} = Users.start_session(user)

      session = Repo.one(from s in Session, where: s.user_id == ^user.id)
      expected = DateTime.add(DateTime.utc_now(), 1, :day)

      assert_in_delta DateTime.diff(session.expires_at, expected, :second), 0, 5
    end

    test "an expired session no longer resolves to its user" do
      user = user_fixture()
      {:ok, token} = Users.start_session(user)

      Repo.update_all(from(s in Session, where: s.user_id == ^user.id),
        set: [expires_at: DateTime.add(DateTime.utc_now(), -1, :second)]
      )

      refute Users.get_user_by_session_token(token)
    end

    test "starting a session prunes other sessions that have expired" do
      user = user_fixture()
      {:ok, stale} = Users.start_session(user)

      Repo.update_all(from(s in Session, where: s.user_id == ^user.id),
        set: [expires_at: DateTime.add(DateTime.utc_now(), -1, :second)]
      )

      {:ok, _fresh} = Users.start_session(user)

      assert Repo.aggregate(from(s in Session, where: s.user_id == ^user.id), :count) == 1
      refute Users.get_user_by_session_token(stale)
    end

    test "ending an unknown token is a no-op" do
      assert :ok = Users.end_session("not-a-real-token")
    end

    test "ending one session leaves the user's other sessions alone" do
      user = user_fixture()
      {:ok, first} = Users.start_session(user)
      {:ok, second} = Users.start_session(user)

      assert :ok = Users.end_session(first)

      refute Users.get_user_by_session_token(first)
      assert Users.get_user_by_session_token(second)
    end
  end

  describe "delete_user_data/1" do
    test "deletes the read-model row, the key, and blocks login" do
      user = user_fixture(%{email: "alice@example.com", password: "hello world!"})

      assert :ok = Users.delete_user_data(user.id)

      refute Users.get_user(user.id)
      refute KeyRepo.get(CryptoKey, user.id)
      refute Users.get_user_by_email_and_password("alice@example.com", "hello world!")
    end

    test "sessions cascade away with the user row" do
      user = user_fixture()
      {:ok, token} = Users.start_session(user)

      assert :ok = Users.delete_user_data(user.id)

      refute Users.get_user_by_session_token(token)
      assert Repo.aggregate(from(s in Session, where: s.user_id == ^user.id), :count) == 0
    end

    test "leaves the linked player untouched" do
      user = user_fixture()
      player = user.player

      assert :ok = Users.delete_user_data(user.id)

      assert Players.get_player(player.id)
    end

    test "releases the email address for re-registration" do
      user = user_fixture(%{email: "alice@example.com"})
      :ok = Users.delete_user_data(user.id)

      assert {:ok, %User{}} =
               Users.register_user_with_new_player(
                 unique_player_name(),
                 "alice@example.com",
                 valid_user_password()
               )
    end
  end
end
