defmodule Fskick.Games.Projectors.Game do
  @moduledoc """
  Projects `GameCreated` events into the `games` read model — one row
  per game carrying the season, kickoff time and outcome.

  This is the lookup surface for `Fskick.Games.add_player_to_game/3`,
  which resolves the game UUID here before dispatching against the
  aggregate. The roster is not stored — `Fskick.Games.PlayerResult`
  already holds one row per (player, game).

  The `name:` is versioned (`.v1`) so a fresh deployment replays from
  the origin of the event store and backfills `games` from every
  existing `GameCreated`.
  """

  use Commanded.Projections.Ecto,
    application: Fskick.App,
    repo: Fskick.Repo,
    name: "Fskick.Games.Projectors.Game.v1"

  alias Fskick.Games.Events.GameCreated

  project(%GameCreated{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :game, %Fskick.Games.Game{
      id: event.game_id,
      season_id: event.season_id,
      played_at: coerce_datetime(event.played_at),
      outcome: event.outcome,
      created_at: metadata.created_at
    })
  end)

  defp coerce_datetime(%DateTime{} = dt), do: dt

  defp coerce_datetime(value) when is_binary(value) do
    {:ok, dt, _offset} = DateTime.from_iso8601(value)
    dt
  end
end
