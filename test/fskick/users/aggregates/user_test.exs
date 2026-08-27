defmodule Fskick.Users.Aggregates.UserTest do
  use ExUnit.Case, async: true

  alias Fskick.Users.Aggregates.User
  alias Fskick.Users.Commands.DeleteUserData
  alias Fskick.Users.Commands.LogInUser
  alias Fskick.Users.Commands.LogOutUser
  alias Fskick.Users.Commands.RegisterUser
  alias Fskick.Users.Events.UserDataDeleted
  alias Fskick.Users.Events.UserLoggedIn
  alias Fskick.Users.Events.UserLoggedOut
  alias Fskick.Users.Events.UserRegistered

  defp registered(user_id \\ Ecto.UUID.generate()) do
    User.apply(%User{}, %UserRegistered{
      user_id: user_id,
      player_id: Ecto.UUID.generate(),
      email: "alice@example.com",
      hashed_password: "hashed"
    })
  end

  describe "execute/2 with RegisterUser" do
    test "emits UserRegistered when the aggregate is uninitialised" do
      id = Ecto.UUID.generate()
      player_id = Ecto.UUID.generate()

      command = %RegisterUser{
        user_id: id,
        player_id: player_id,
        email: "alice@example.com",
        hashed_password: "hashed"
      }

      assert %UserRegistered{user_id: ^id, player_id: ^player_id, email: "alice@example.com"} =
               User.execute(%User{}, command)
    end

    test "rejects re-registration" do
      assert {:error, :already_created} = User.execute(registered(), %RegisterUser{})
    end
  end

  describe "execute/2 with DeleteUserData" do
    test "emits UserDataDeleted for a registered user" do
      id = Ecto.UUID.generate()

      assert %UserDataDeleted{user_id: ^id} =
               User.execute(registered(id), %DeleteUserData{user_id: id})
    end

    test "rejects an unknown user" do
      assert {:error, :not_found} = User.execute(%User{}, %DeleteUserData{})
    end
  end

  describe "execute/2 with LogInUser" do
    test "emits UserLoggedIn for a registered user" do
      id = Ecto.UUID.generate()
      session_id = Ecto.UUID.generate()
      expires_at = "2026-08-28T10:00:00.000000Z"

      command = %LogInUser{user_id: id, session_id: session_id, expires_at: expires_at}

      assert %UserLoggedIn{user_id: ^id, session_id: ^session_id, expires_at: ^expires_at} =
               User.execute(registered(id), command)
    end

    test "rejects an unknown user" do
      assert {:error, :not_found} = User.execute(%User{}, %LogInUser{})
    end
  end

  describe "execute/2 with LogOutUser" do
    test "emits UserLoggedOut for a registered user" do
      id = Ecto.UUID.generate()
      session_id = Ecto.UUID.generate()

      assert %UserLoggedOut{user_id: ^id, session_id: ^session_id} =
               User.execute(registered(id), %LogOutUser{user_id: id, session_id: session_id})
    end

    test "rejects an unknown user" do
      assert {:error, :not_found} = User.execute(%User{}, %LogOutUser{})
    end
  end

  describe "apply/2" do
    test "UserRegistered marks the aggregate registered" do
      id = Ecto.UUID.generate()
      player_id = Ecto.UUID.generate()

      event = %UserRegistered{
        user_id: id,
        player_id: player_id,
        email: "alice@example.com",
        hashed_password: "hashed"
      }

      assert %User{user_id: ^id, player_id: ^player_id, registered?: true} =
               User.apply(%User{}, event)
    end

    test "UserDataDeleted leaves the state untouched" do
      state = registered()

      assert User.apply(state, %UserDataDeleted{user_id: state.user_id}) == state
    end

    test "UserLoggedIn leaves the state untouched, so it does not grow per session" do
      state = registered()

      event = %UserLoggedIn{
        user_id: state.user_id,
        session_id: Ecto.UUID.generate(),
        expires_at: "2026-08-28T10:00:00.000000Z"
      }

      assert User.apply(state, event) == state
    end

    test "UserLoggedOut leaves the state untouched" do
      state = registered()
      event = %UserLoggedOut{user_id: state.user_id, session_id: Ecto.UUID.generate()}

      assert User.apply(state, event) == state
    end
  end
end
