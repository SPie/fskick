defmodule Fskick.Users.Aggregates.User do
  @moduledoc """
  User aggregate root. Enforces state-dependent invariants only —
  structural validation lives on the command.

  The aggregate deliberately holds **no PII** (no email) so that Commanded
  snapshots of its state never carry personal data.
  """

  alias Fskick.Users.Aggregates.User
  alias Fskick.Users.Commands.DeleteUserData
  alias Fskick.Users.Commands.LogInUser
  alias Fskick.Users.Commands.LogOutUser
  alias Fskick.Users.Commands.RegisterUser
  alias Fskick.Users.Events.UserDataDeleted
  alias Fskick.Users.Events.UserLoggedIn
  alias Fskick.Users.Events.UserLoggedOut
  alias Fskick.Users.Events.UserRegistered

  defstruct [:user_id, :player_id]

  def execute(%User{user_id: nil}, %RegisterUser{} = command) do
    %UserRegistered{
      user_id: command.user_id,
      player_id: command.player_id,
      email: command.email,
      hashed_password: command.hashed_password
    }
  end

  def execute(%User{}, %RegisterUser{}) do
    {:error, :already_created}
  end

  def execute(%User{user_id: nil}, %DeleteUserData{}) do
    {:error, :not_found}
  end

  def execute(%User{user_id: id}, %DeleteUserData{}) do
    %UserDataDeleted{user_id: id}
  end

  def execute(%User{user_id: nil}, %LogInUser{}) do
    {:error, :not_found}
  end

  def execute(%User{}, %LogInUser{} = command) do
    %UserLoggedIn{
      user_id: command.user_id,
      session_id: command.session_id,
      expires_at: command.expires_at
    }
  end

  def execute(%User{user_id: nil}, %LogOutUser{}) do
    {:error, :not_found}
  end

  def execute(%User{}, %LogOutUser{} = command) do
    %UserLoggedOut{user_id: command.user_id, session_id: command.session_id}
  end

  def apply(%User{} = state, %UserRegistered{user_id: id, player_id: player_id}) do
    %User{state | user_id: id, player_id: player_id}
  end

  def apply(%User{} = state, %UserDataDeleted{}) do
    state
  end

  # Login and logout are audit history: they append to the user stream but leave
  # the aggregate state untouched, so state does not grow with every session.
  # (The stream does grow, which lengthens aggregate rebuilds; if that ever
  # matters, Commanded snapshotting is the lever.)
  def apply(%User{} = state, %UserLoggedIn{}), do: state

  def apply(%User{} = state, %UserLoggedOut{}), do: state
end
