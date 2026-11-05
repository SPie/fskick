defmodule Fskick.Users.Projectors.UserTest do
  use Fskick.DataCase

  alias Fskick.EventStore.JsonSerializer
  alias Fskick.Users.Events.UserDataDeleted
  alias Fskick.Users.Events.UserRegistered
  alias Fskick.Users.Projectors.User, as: Projector
  alias Fskick.Users.User

  describe "replaying erased users" do
    test "two users whose email decrypted to the tombstone do not collide" do
      # Once a user's crypto key is deleted, the serializer hands the projector
      # the same "[redacted]" string for every one of them — while the unique
      # index on users.email says otherwise. On replay both registrations land
      # before either deletion does.
      alice = Ecto.UUID.generate()
      bob = Ecto.UUID.generate()

      assert :ok = project(registered(alice), 1)
      assert :ok = project(registered(bob), 2)

      assert %User{email: alice_email} = Repo.get(User, alice)
      assert %User{email: bob_email} = Repo.get(User, bob)
      assert alice_email != bob_email

      assert :ok = project(%UserDataDeleted{user_id: alice}, 3)
      assert :ok = project(%UserDataDeleted{user_id: bob}, 4)

      refute Repo.get(User, alice)
      refute Repo.get(User, bob)
    end

    test "a live user's email is projected verbatim" do
      id = Ecto.UUID.generate()

      assert :ok = project(%{registered(id) | email: "alice@example.com"}, 1)

      assert %User{email: "alice@example.com"} = Repo.get(User, id)
    end
  end

  defp registered(user_id) do
    %UserRegistered{
      user_id: user_id,
      player_id: Ecto.UUID.generate(),
      email: JsonSerializer.tombstone(),
      hashed_password: "$argon2id$hash"
    }
  end

  # Drives the projector directly. The handler name is unique per test run so
  # the version tracking never contends with the running projector's own row.
  defp project(event, event_number) do
    Projector.handle(event, %{
      handler_name: "test-#{inspect(self())}",
      event_number: event_number,
      created_at: DateTime.utc_now()
    })
  end
end
