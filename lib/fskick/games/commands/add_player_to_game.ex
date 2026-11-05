defmodule Fskick.Games.Commands.AddPlayerToGame do
  @moduledoc """
  Command to append a player to one of the teams of an already-recorded
  game — someone who turned up late, or who was missed when the game
  was entered.

  Structural validation lives here: presence of the game, the player and
  a valid team. Game and player existence is checked at the context
  layer (read-model lookups) before the command is built; whether the
  player is already in the game is a state-dependent invariant enforced
  by `Fskick.Games.Aggregates.Game`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @teams [:team_a, :team_b]

  @primary_key false
  embedded_schema do
    field :game_id, :binary_id
    field :player_id, :binary_id
    field :team, Ecto.Enum, values: @teams
  end

  @doc """
  Build a validated `%AddPlayerToGame{}` from raw attrs.

  Returns `{:ok, command}` or `{:error, changeset}`.
  """
  def new(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:game_id, :player_id, :team])
    |> validate_required([:game_id, :player_id, :team])
    |> apply_action(:insert)
  end
end
