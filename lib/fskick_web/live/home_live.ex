defmodule FskickWeb.HomeLive do
  use FskickWeb, :live_view
  import FskickWeb.Components.PlayerStatsTable

  alias Fskick.Games
  alias Fskick.Players
  alias Fskick.Seasons

  @allowed_sorts ~w(points wins games win_ratio)

  def mount(_params, _session, socket) do
    seasons = Seasons.list_seasons()
    active_season = Seasons.get_active_season() || List.first(seasons)

    {:ok,
     socket
     |> assign(seasons: seasons, active_season: active_season, sort: :points)
     |> load_stats()}
  end

  def handle_event("change_season", %{"season" => uuid}, socket) do
    case Enum.find(socket.assigns.seasons, &(&1.id == uuid)) do
      nil -> {:noreply, socket}
      season -> {:noreply, socket |> assign(:active_season, season) |> load_stats()}
    end
  end

  def handle_event("sort", %{"sort" => key}, socket) when key in @allowed_sorts do
    {:noreply,
     socket
     |> assign(:sort, String.to_existing_atom(key))
     |> load_stats()}
  end

  defp load_stats(socket) do
    case socket.assigns.active_season do
      nil ->
        assign(socket, stats: [], games_count: 0)

      season ->
        stats = Players.list_player_stats(season_id: season.id, sort: socket.assigns.sort)
        assign(socket, stats: stats, games_count: Games.season_game_count(season.id))
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <h2 class="text-center text-md md:text-2xl font-bold">
        Season
        <form :if={@seasons != []} class="inline" phx-change="change_season">
          <select name="season" class="bg-gray-900">
            <option
              :for={s <- @seasons}
              value={s.id}
              selected={@active_season && s.id == @active_season.id}
            >
              {s.name}
            </option>
          </select>
        </form>
      </h2>

      <div>
        <.player_stats_table
          stats={@stats}
          games_count={@games_count}
          sort={@sort}
          highlight_player_id={highlight_id(@current_scope)}
        />
      </div>
    </Layouts.app>
    """
  end
end
