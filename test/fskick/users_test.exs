defmodule Fskick.UsersTest do
  use Fskick.DataCase

  import Ecto.Query, only: [from: 2]
  import Fskick.UsersFixtures

  alias Fskick.Players
  alias Fskick.Users
  alias Fskick.Users.CryptoKey
  alias Fskick.Users.User
  alias Fskick.Users.UserToken

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

      assert Repo.get(CryptoKey, user.id)
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

      player = Users.get_linked_player(user)
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

  describe "session tokens" do
    test "generate, look up, and delete a session token" do
      user = user_fixture()

      token = Users.generate_user_session_token(user)
      assert %User{id: id} = Users.get_user_by_session_token(token)
      assert id == user.id

      :ok = Users.delete_user_session_token(token)
      refute Users.get_user_by_session_token(token)
    end
  end

  describe "delete_user_data/1" do
    test "deletes the read-model row, the key, and blocks login" do
      user = user_fixture(%{email: "alice@example.com", password: "hello world!"})

      assert :ok = Users.delete_user_data(user.id)

      refute Users.get_user(user.id)
      refute Repo.get(CryptoKey, user.id)
      refute Users.get_user_by_email_and_password("alice@example.com", "hello world!")
    end

    test "session tokens cascade away with the user row" do
      user = user_fixture()
      token = Users.generate_user_session_token(user)

      assert :ok = Users.delete_user_data(user.id)

      refute Users.get_user_by_session_token(token)
      assert Repo.aggregate(from(t in UserToken, where: t.user_id == ^user.id), :count) == 0
    end

    test "leaves the linked player untouched" do
      user = user_fixture()
      player = Users.get_linked_player(user)

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
