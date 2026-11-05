defmodule Fskick.Games do
  @moduledoc """
  Games context: write side dispatches `CreateGame` and
  `AddPlayerToGame` commands through `Fskick.App`, then waits for the
  projectors to catch up so the read model is consistent on return.

  Player names, the season name and the game UUID are resolved against
  their existing read models before a command is built, so commands
  carry UUIDs only.
  """

  import Ecto.Query, only: [from: 2]

  alias Fskick.App
  alias Fskick.CQRS.Projection
  alias Fskick.Games.Commands.AddPlayerToGame
  alias Fskick.Games.Commands.CreateGame
  alias Fskick.Games.Game
  alias Fskick.Games.GameCount
  alias Fskick.Games.PlayerResult
  alias Fskick.Games.PlayerStats
  alias Fskick.Players
  alias Fskick.Players.Player
  alias Fskick.Repo
  alias Fskick.Seasons

  @doc """
  Record a new game.

  `attrs` is a map with:
  - `:team_a_names` — list of player names (required, non-empty)
  - `:team_b_names` — list of player names (required, non-empty)
  - `:outcome` — `:team_a_won | :team_b_won | :draw` (required)
  - `:played_at` — `DateTime.t()` (optional; defaults to `DateTime.utc_now/0`)
  - `:season_name` — string (optional; defaults to the active season)

  Returns `{:ok, %CreateGame{}}` on success, or:
  - `{:error, :no_active_season}` if `:season_name` is omitted and none is active
  - `{:error, {:season_not_found, name}}` if the named season does not exist
  - `{:error, {:players_not_found, [name, ...]}}` for unknown player names
  - `{:error, %Ecto.Changeset{}}` for structural validation failures
  - `{:error, reason}` for dispatch failures
  """
  def create_game(attrs) when is_map(attrs) do
    with {:ok, season} <- resolve_season(Map.get(attrs, :season_name)),
         {:ok, team_a_ids} <- resolve_players(Map.get(attrs, :team_a_names, [])),
         {:ok, team_b_ids} <- resolve_players(Map.get(attrs, :team_b_names, [])),
         before_count = season_game_count(season.id),
         {:ok, %CreateGame{} = command} <-
           CreateGame.new(%{
             game_id: Ecto.UUID.generate(),
             season_id: season.id,
             played_at: Map.get(attrs, :played_at) || DateTime.utc_now(),
             team_a: team_a_ids,
             team_b: team_b_ids,
             outcome: Map.get(attrs, :outcome)
           }),
         :ok <- App.dispatch(command),
         {:ok, _} <-
           Projection.await(GameCount, season.id, match: &(&1.total > before_count)) do
      {:ok, command}
    end
  end

  defp resolve_season(nil) do
    case Seasons.get_active_season() do
      nil -> {:error, :no_active_season}
      season -> {:ok, season}
    end
  end

  defp resolve_season(name) when is_binary(name) do
    case Seasons.get_season_by_name(name) do
      nil -> {:error, {:season_not_found, name}}
      season -> {:ok, season}
    end
  end

  defp resolve_players(names) when is_list(names) do
    trimmed =
      names
      |> Enum.map(&trim/1)
      |> Enum.reject(&(&1 == ""))

    found =
      Repo.all(from p in Player, where: p.name in ^trimmed, select: {p.name, p.id})
      |> Map.new()

    case Enum.split_with(trimmed, &Map.has_key?(found, &1)) do
      {_present, []} ->
        {:ok, Enum.map(trimmed, &Map.fetch!(found, &1))}

      {_present, missing} ->
        {:error, {:players_not_found, Enum.uniq(missing)}}
    end
  end

  defp trim(value) when is_binary(value), do: String.trim(value)

  @doc """
  Add a player to a game that has already been recorded — someone who
  turned up late, or who was missed when the game was entered.

  `game_id` is the game's UUID, `player_name` the player's name, and
  `team` either `:team_a` or `:team_b`. The player inherits the game's
  season, kickoff time and outcome, so their result slots into the right
  chronological position in every streak and ranking.

  Returns `{:ok, %AddPlayerToGame{}}` on success, or:
  - `{:error, {:game_not_found, game_id}}` if no such game exists
  - `{:error, {:player_not_found, name}}` if no such player exists
  - `{:error, :already_in_game}` if the player is already on either team
  - `{:error, %Ecto.Changeset{}}` for structural validation failures
  - `{:error, reason}` for dispatch failures
  """
  def add_player_to_game(game_id, player_name, team) do
    with {:ok, game} <- resolve_game(game_id),
         {:ok, player} <- resolve_player(player_name),
         before_games = player_season_games(game.season_id, player.id),
         {:ok, %AddPlayerToGame{} = command} <-
           AddPlayerToGame.new(%{
             game_id: game.id,
             player_id: player.id,
             team: team
           }),
         :ok <- App.dispatch(command),
         {:ok, _} <- Projection.await_by(PlayerResult, player_id: player.id, game_id: game.id),
         {:ok, _} <-
           Projection.await_by(PlayerStats, [season_id: game.season_id, player_id: player.id],
             match: &(&1.games > before_games)
           ) do
      {:ok, command}
    end
  end

  defp resolve_game(game_id) when is_binary(game_id) do
    with {:ok, uuid} <- Ecto.UUID.cast(game_id),
         %Game{} = game <- Repo.get(Game, uuid) do
      {:ok, game}
    else
      _ -> {:error, {:game_not_found, game_id}}
    end
  end

  defp resolve_player(name) when is_binary(name) do
    case Players.get_player_by_name(String.trim(name)) do
      nil -> {:error, {:player_not_found, name}}
      player -> {:ok, player}
    end
  end

  # `player_stats` rows are created lazily, so an absent row means zero.
  defp player_season_games(season_id, player_id) do
    case Repo.get_by(PlayerStats, season_id: season_id, player_id: player_id) do
      nil -> 0
      %PlayerStats{games: games} -> games
    end
  end

  @doc """
  Returns the total number of games recorded across all seasons.

  Derived from the per-season `game_counts` rows maintained by
  `Fskick.Games.Projectors.PlayerStats` — `SUM(total)` across every
  season that has had at least one game.
  """
  def total_games_count() do
    Repo.aggregate(GameCount, :sum, :total) || 0
  end

  @doc """
  Returns the number of games recorded in the given season.

  Reads from the `game_counts` row keyed on `season_id`. Returns `0`
  when the season has had no games (the projector creates the row
  lazily on first game).
  """
  def season_game_count(season_id) do
    case Repo.get(GameCount, season_id) do
      nil -> 0
      %GameCount{total: total} -> total
    end
  end
end
