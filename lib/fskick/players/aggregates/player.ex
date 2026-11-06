defmodule Fskick.Players.Aggregates.Player do
  @moduledoc """
  Player aggregate root. Enforces state-dependent invariants only —
  structural validation lives on the command.
  """

  alias Fskick.Players.Aggregates.Player
  alias Fskick.Players.Commands.CreatePlayer
  alias Fskick.Players.Commands.RenamePlayer
  alias Fskick.Players.Events.PlayerCreated
  alias Fskick.Players.Events.PlayerRenamed

  defstruct [:player_id, :name]

  def execute(%Player{player_id: nil}, %CreatePlayer{player_id: id, name: name}) do
    %PlayerCreated{player_id: id, name: name}
  end

  def execute(%Player{}, %CreatePlayer{}) do
    {:error, :already_created}
  end

  def execute(%Player{player_id: nil}, %RenamePlayer{}) do
    {:error, :not_found}
  end

  # Renaming to the current name is a no-op, so a double submit records nothing.
  def execute(%Player{name: name}, %RenamePlayer{name: name}) do
    []
  end

  def execute(%Player{}, %RenamePlayer{player_id: id, name: name}) do
    %PlayerRenamed{player_id: id, name: name}
  end

  def apply(%Player{} = state, %PlayerCreated{player_id: id, name: name}) do
    %Player{state | player_id: id, name: name}
  end

  def apply(%Player{} = state, %PlayerRenamed{name: name}) do
    %Player{state | name: name}
  end
end
