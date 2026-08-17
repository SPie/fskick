defmodule Fskick.Users.Aggregates.User do
  @moduledoc """
  User aggregate root. Enforces state-dependent invariants only —
  structural validation lives on the command.

  The aggregate deliberately holds **no PII** (no email) so that Commanded
  snapshots of its state never carry personal data.
  """

  alias Fskick.Users.Aggregates.User
  alias Fskick.Users.Commands.DeleteUserData
  alias Fskick.Users.Commands.RegisterUser
  alias Fskick.Users.Events.UserDataDeleted
  alias Fskick.Users.Events.UserRegistered

  defstruct [:user_id, :player_id, registered?: false]

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

  def execute(%User{registered?: true, user_id: id}, %DeleteUserData{}) do
    %UserDataDeleted{user_id: id}
  end

  def execute(%User{}, %DeleteUserData{}) do
    {:error, :not_found}
  end

  def apply(%User{} = state, %UserRegistered{user_id: id, player_id: player_id}) do
    %User{state | user_id: id, player_id: player_id, registered?: true}
  end

  def apply(%User{} = state, %UserDataDeleted{}) do
    state
  end
end
