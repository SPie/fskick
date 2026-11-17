defmodule Fskick.Players do
  @moduledoc """
  Players context: write side dispatches commands through `Fskick.App`;
  read side queries the `Fskick.Players.Player` projection and, for
  rankings, joins with `Fskick.Games.PlayerStats`.
  """

  import Ecto.Query, only: [from: 2, select_merge: 3]

  alias Fskick.App
  alias Fskick.CQRS.Projection
  alias Fskick.Games
  alias Fskick.Games.PlayerResult
  alias Fskick.Games.PlayerStats
  alias Fskick.Players.Commands.CreatePlayer
  alias Fskick.Players.Commands.RenamePlayer
  alias Fskick.Players.Player
  alias Fskick.Players.PlayerStat
  alias Fskick.Repo

  @valid_sorts [:points, :wins, :games, :win_ratio]

  @doc """
  Create a new player with the given name.

  Returns `{:ok, %Player{}}` on success, or:
  - `{:error, %Ecto.Changeset{}}` when the name is blank/invalid or already taken
  - `{:error, :projection_timeout}` if the read model does not catch up in time
  - `{:error, reason}` for dispatch failures
  """
  def create_player(name) do
    attrs = %{player_id: Ecto.UUID.generate(), name: name}

    with {:ok, %CreatePlayer{} = command} <- CreatePlayer.new(attrs),
         :ok <- App.dispatch(command) do
      Projection.await(Player, command.player_id)
    end
  end

  @doc """
  Wait until the read model shows the name from a dispatched `%RenamePlayer{}`.

  Returns `{:ok, %Player{}}`, or `{:error, :projection_timeout}` if the read
  model does not catch up in time.
  """
  def await_renamed(%RenamePlayer{player_id: player_id, name: name}) do
    Projection.await(Player, player_id, match: &(&1.name == name))
  end

  def get_player_by_name(name) when is_binary(name) do
    Repo.get_by(Player, name: name)
  end

  def get_player(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get(Player, uuid)
      :error -> nil
    end
  end

  @doc """
  Returns a ranked list of `%Fskick.Players.PlayerStat{}` rows for every
  player who has played at least one game.

  Derivations:
  - `points = wins * 3 / max(games, div(max_games_across_players, 2))`
  - `win_ratio = wins / games`
  - `games_ratio = games / total_games`

  A `:draw` outcome counts as a win for both teams (handled by the
  projector).

  ## Options

  - `:sort` — one of `#{inspect(@valid_sorts)}`. Defaults to `:points`.
    Sort is descending; `:games` is used as a tiebreaker. Players sharing
    the primary sort value share a position.
  - `:season_id` — when present, scopes the stats to a single season:
    rows come from `Fskick.Games.PlayerStats` filtered to that season,
    and `games_ratio` is `games / season_total_games`. When omitted,
    rows are aggregated across all seasons via `GROUP BY player_id` and
    `games_ratio` is `games / all_time_total_games`. Defaults to
    all-time.
  """
  def list_player_stats(opts \\ []) do
    sort = Keyword.get(opts, :sort, :points)
    validate_sort!(sort)

    {rows, total_games} =
      case Keyword.fetch(opts, :season_id) do
        {:ok, season_id} ->
          {load_season_rows(season_id), Games.season_game_count(season_id)}

        :error ->
          {load_all_time_rows(), Games.total_games_count()}
      end

    max_games = Enum.reduce(rows, 0, fn row, acc -> max(row.games, acc) end)

    rows
    |> Enum.map(&derive(&1, total_games, max_games))
    |> Enum.sort_by(&sort_key(&1, sort), :desc)
    |> assign_positions(sort)
  end

  @doc """
  Returns the target player's top fellow teammates, ranked over games where
  both shared a team. All-time.

  ## Options

  - `:sort` — one of `#{inspect(@valid_sorts)}`. Default `:points`. Same
    semantics as `list_player_stats/1`.
  - `:limit` — number of rows to return. Default `5`. The list is sorted by
    the chosen key first, then truncated — so changing `:sort` can change
    which players appear (matching the old Go app's `getFavoriteTeamOf5`
    behaviour).

  The `games_ratio` percentage uses the target's own total games as the
  denominator, so 100% means "always played together".
  """
  def favorite_team(player_id, opts \\ []) when is_binary(player_id) do
    team_ranking(player_id, :win, opts)
  end

  @doc """
  Returns the target player's teammates ranked by games lost together, all-time.

  The least-favorite mirror of `favorite_team/2`: the `wins`/`win_ratio` fields
  carry loss counts instead. A draw counts as a shared game but not a loss.
  Same `:sort` / `:limit` options and semantics as `favorite_team/2`.
  """
  def least_favorite_team(player_id, opts \\ []) when is_binary(player_id) do
    team_ranking(player_id, :loss, opts)
  end

  defp team_ranking(player_id, outcome, opts) do
    rank(load_teammate_rows(player_id, outcome), player_id, opts)
  end

  @doc """
  Total number of games the player has played (all-time, all seasons).
  """
  def count_player_games(player_id) when is_binary(player_id) do
    Repo.aggregate(
      from(r in PlayerResult, where: r.player_id == ^player_id),
      :count
    )
  end

  @doc """
  Returns the target player's top opponents, ranked over games where they
  played on opposite teams. All-time.

  ## Options

  - `:sort` — one of `#{inspect(@valid_sorts)}`. Default `:points`.
  - `:limit` — number of rows to return. Default `5`. Same sort-then-take
    semantics as `favorite_team/2`.

  A draw counts as a `game-against` but not a `win-against`: a `win` is only
  credited when the target's team strictly beat the opponent's team. The
  `games_ratio` percentage uses the target's own total games as the
  denominator, matching `favorite_team/2`.
  """
  def favorite_opponents(player_id, opts \\ []) when is_binary(player_id) do
    opponent_ranking(player_id, :win, opts)
  end

  @doc """
  Returns the target player's opponents ranked by games lost against, all-time.

  The least-favorite mirror of `favorite_opponents/2`: the `wins`/`win_ratio`
  fields carry loss-against counts instead. A loss-against is credited only when
  the opponent's team strictly beat the target's team; a draw counts as a
  game-against but not a loss-against. Same `:sort` / `:limit` options and
  semantics as `favorite_opponents/2`.
  """
  def least_favorite_opponents(player_id, opts \\ []) when is_binary(player_id) do
    opponent_ranking(player_id, :loss, opts)
  end

  defp opponent_ranking(player_id, outcome, opts) do
    load_opponent_rows(player_id, outcome)
    |> rank(player_id, opts)
  end

  defp rank(rows, player_id, opts) do
    sort = Keyword.get(opts, :sort, :points)
    limit = Keyword.get(opts, :limit, 5)
    validate_sort!(sort)

    target_games = count_player_games(player_id)
    max_games = Enum.reduce(rows, 0, fn row, acc -> max(row.games, acc) end)

    rows
    |> Enum.map(&derive(&1, target_games, max_games))
    |> Enum.sort_by(&sort_key(&1, sort), :desc)
    |> assign_positions(sort)
    |> Enum.take(limit)
  end

  defp validate_sort!(sort) do
    unless sort in @valid_sorts do
      raise ArgumentError,
            "invalid sort: #{inspect(sort)}; expected one of #{inspect(@valid_sorts)}"
    end
  end

  defp load_all_time_rows() do
    Repo.all(
      from s in PlayerStats,
        join: p in Player,
        on: p.id == s.player_id,
        group_by: [s.player_id, p.name],
        select: %{
          player_id: s.player_id,
          name: p.name,
          wins: type(sum(s.wins), :integer),
          games: type(sum(s.games), :integer)
        }
    )
  end

  defp load_season_rows(season_id) do
    Repo.all(
      from s in PlayerStats,
        join: p in Player,
        on: p.id == s.player_id,
        where: s.season_id == ^season_id,
        select: %{
          player_id: s.player_id,
          name: p.name,
          wins: s.wins,
          games: s.games
        }
    )
  end

  defp load_teammate_rows(player_id, outcome) do
    from(t in PlayerResult,
      where: t.player_id == ^player_id,
      join: f in PlayerResult,
      on:
        f.game_id == t.game_id and f.team == t.team and
          f.player_id != t.player_id,
      join: p in Player,
      on: p.id == f.player_id,
      group_by: [f.player_id, p.name],
      select: %{
        player_id: f.player_id,
        name: p.name,
        games: type(count(f.game_id), :integer)
      }
    )
    |> merge_teammate_count(outcome)
    |> Repo.all()
  end

  # Teammates share the target's result, so the outcome only depends on `f.won`.
  defp merge_teammate_count(query, :win) do
    select_merge(query, [t, f, p], %{
      wins: type(sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", f.won)), :integer)
    })
  end

  defp merge_teammate_count(query, :loss) do
    select_merge(query, [t, f, p], %{
      wins: type(sum(fragment("CASE WHEN NOT ? THEN 1 ELSE 0 END", f.won)), :integer)
    })
  end

  defp load_opponent_rows(player_id, outcome) do
    from(t in PlayerResult,
      where: t.player_id == ^player_id,
      join: f in PlayerResult,
      on: f.game_id == t.game_id and f.team != t.team,
      join: p in Player,
      on: p.id == f.player_id,
      group_by: [f.player_id, p.name],
      select: %{
        player_id: f.player_id,
        name: p.name,
        games: type(count(f.game_id), :integer)
      }
    )
    |> merge_opponent_count(outcome)
    |> Repo.all()
  end

  # A win-against needs the target's team to strictly beat the opponent's;
  # a loss-against is the mirror. Draws (`won` true on both sides) count as neither.
  defp merge_opponent_count(query, :win) do
    select_merge(query, [t, f, p], %{
      wins: type(sum(fragment("CASE WHEN ? AND NOT ? THEN 1 ELSE 0 END", t.won, f.won)), :integer)
    })
  end

  defp merge_opponent_count(query, :loss) do
    select_merge(query, [t, f, p], %{
      wins: type(sum(fragment("CASE WHEN NOT ? AND ? THEN 1 ELSE 0 END", t.won, f.won)), :integer)
    })
  end

  defp derive(
         %{player_id: player_id, name: name, wins: wins, games: games},
         total_games,
         max_games
       ) do
    %PlayerStat{
      player_id: player_id,
      name: name,
      wins: wins,
      games: games,
      points: points(wins, games, max_games),
      win_ratio: ratio(wins, games),
      games_ratio: ratio(games, total_games)
    }
  end

  defp points(_wins, 0, _max_games), do: 0.0

  defp points(wins, games, max_games) do
    divisor = max(games, div(max_games, 2))
    wins * 3 / divisor
  end

  defp ratio(_num, 0), do: 0
  defp ratio(num, denom), do: num / denom * 100

  defp sort_key(stat, :points), do: {stat.points, stat.games}
  defp sort_key(stat, :wins), do: {stat.wins, stat.games}
  defp sort_key(stat, :games), do: {stat.games, stat.wins}
  defp sort_key(stat, :win_ratio), do: {stat.win_ratio, stat.games}

  defp position_value(stat, :points), do: stat.points
  defp position_value(stat, :wins), do: stat.wins
  defp position_value(stat, :games), do: stat.games
  defp position_value(stat, :win_ratio), do: stat.win_ratio

  defp assign_positions(sorted, sort) do
    {result, _acc} =
      sorted
      |> Enum.with_index(1)
      |> Enum.map_reduce({nil, 1}, fn {%PlayerStat{} = stat, idx}, {prev_value, prev_pos} ->
        value = position_value(stat, sort)
        position = if value == prev_value, do: prev_pos, else: idx
        {%PlayerStat{stat | position: position}, {value, position}}
      end)

    result
  end
end
