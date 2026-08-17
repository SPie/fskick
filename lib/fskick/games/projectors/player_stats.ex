defmodule Fskick.Games.Projectors.PlayerStats do
  @moduledoc """
  Projects `GameCreated` and `PlayerAddedToGame` events into the
  per-(season, player) read models that back the rankings tables:

  - `player_stats` — per-(season, player) counters (`wins`, `games`)
  - `game_counts` — per-season game total, advanced by `GameCreated`
    only: adding a player to an existing game does not create a game

  A `:draw` outcome counts as a win for both teams, matching the product
  rule that a draw is treated like a win in the rankings.

  Derived stats (points, ratios, position) are **not** stored here —
  they depend on global aggregates (total games, max games across
  players) that would force a write to every row on every event.
  Read-side derivation lives in `Fskick.Players.list_player_stats/1`,
  which also derives all-time numbers via `GROUP BY player_id`.

  The `name:` is versioned (`.v2`) so this projector replays from origin
  against the consolidated tables introduced by the
  `ConsolidatePlayerStatsPerSeason` migration.
  """

  use Commanded.Projections.Ecto,
    application: Fskick.App,
    repo: Fskick.Repo,
    name: "Fskick.Games.Projectors.PlayerStats.v2"

  alias Fskick.Games.Events.GameCreated
  alias Fskick.Games.Events.PlayerAddedToGame
  alias Fskick.Games.GameCount
  alias Fskick.Games.PlayerStats

  project(%GameCreated{} = event, _metadata, fn multi ->
    team_a_win_inc = win_inc(event.outcome, :team_a)
    team_b_win_inc = win_inc(event.outcome, :team_b)

    multi
    |> upsert_team(event.season_id, :team_a, event.team_a, team_a_win_inc)
    |> upsert_team(event.season_id, :team_b, event.team_b, team_b_win_inc)
    |> Ecto.Multi.insert(
      :game_count,
      %GameCount{season_id: event.season_id, total: 1},
      on_conflict: [inc: [total: 1]],
      conflict_target: :season_id
    )
  end)

  # Adding a player to an existing game is not a new game, so
  # `game_counts` is deliberately left alone here.
  project(%PlayerAddedToGame{} = event, _metadata, fn multi ->
    team = team_tag(event.team)

    upsert_team(multi, event.season_id, team, [event.player_id], win_inc(event.outcome, team))
  end)

  # The event carries the team as a string because that is its JSON wire
  # format; the atoms below are this projector's internal vocabulary.
  defp team_tag("team_a"), do: :team_a
  defp team_tag("team_b"), do: :team_b

  defp win_inc("team_a_won", :team_a), do: 1
  defp win_inc("team_b_won", :team_b), do: 1
  defp win_inc("draw", _team), do: 1
  defp win_inc(_outcome, _team), do: 0

  defp upsert_team(multi, season_id, tag, player_ids, win_inc) do
    player_ids
    |> Enum.with_index()
    |> Enum.reduce(multi, fn {player_id, idx}, acc ->
      Ecto.Multi.insert(
        acc,
        {:player_stats, tag, idx},
        %PlayerStats{
          season_id: season_id,
          player_id: player_id,
          wins: win_inc,
          games: 1
        },
        on_conflict: [inc: [wins: win_inc, games: 1]],
        conflict_target: [:season_id, :player_id]
      )
    end)
  end
end
