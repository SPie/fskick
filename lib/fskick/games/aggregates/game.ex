defmodule Fskick.Games.Aggregates.Game do
  @moduledoc """
  Game aggregate root. Enforces state-dependent invariants only —
  structural validation lives on the command.

  The roster is held as a `player_id => :team_a | :team_b` map rather
  than two team lists: membership is the only question the aggregate
  ever asks of it, and a map makes that an `is_map_key/2` guard, so
  every invariant stays an `execute/2` head. Team ordering is a
  read-model concern — the events carry it, `Fskick.Games.PlayerResult`
  records it.

  Events carry the team as a **string**, like `outcome` does. They are
  JSON in the event store and `Fskick.EventStore.JsonSerializer` decodes
  with `keys: :atoms!`, which atomises keys but not values — so an atom
  written into an event would come back as a string whenever the
  aggregate is rebuilt from the store. Writing the string form keeps
  both paths identical; `team/1` converts back at that boundary.
  """

  alias Fskick.Games.Aggregates.Game
  alias Fskick.Games.Commands.AddPlayerToGame
  alias Fskick.Games.Commands.CreateGame
  alias Fskick.Games.Events.GameCreated
  alias Fskick.Games.Events.PlayerAddedToGame

  defstruct [:game_id, :season_id, :played_at, :outcome, roster: %{}]

  def execute(%Game{game_id: nil}, %CreateGame{} = command) do
    %GameCreated{
      game_id: command.game_id,
      season_id: command.season_id,
      played_at: command.played_at,
      team_a: command.team_a,
      team_b: command.team_b,
      outcome: Atom.to_string(command.outcome)
    }
  end

  def execute(%Game{}, %CreateGame{}) do
    {:error, :already_created}
  end

  def execute(%Game{game_id: nil}, %AddPlayerToGame{}) do
    {:error, :not_found}
  end

  def execute(%Game{roster: roster}, %AddPlayerToGame{player_id: player_id})
      when is_map_key(roster, player_id) do
    {:error, :already_in_game}
  end

  def execute(%Game{} = state, %AddPlayerToGame{} = command) do
    # The season, kickoff time and outcome are enriched from aggregate
    # state so projectors never have to look the game up.
    %PlayerAddedToGame{
      game_id: command.game_id,
      player_id: command.player_id,
      team: Atom.to_string(command.team),
      season_id: state.season_id,
      played_at: state.played_at,
      outcome: state.outcome
    }
  end

  def apply(%Game{} = state, %GameCreated{} = event) do
    %Game{
      state
      | game_id: event.game_id,
        season_id: event.season_id,
        played_at: event.played_at,
        outcome: event.outcome,
        roster: Map.merge(roster(event.team_a, :team_a), roster(event.team_b, :team_b))
    }
  end

  def apply(%Game{} = state, %PlayerAddedToGame{} = event) do
    %Game{state | roster: Map.put(state.roster, event.player_id, team(event.team))}
  end

  defp roster(player_ids, team), do: Map.new(player_ids, &{&1, team})

  defp team("team_a"), do: :team_a
  defp team("team_b"), do: :team_b
end
