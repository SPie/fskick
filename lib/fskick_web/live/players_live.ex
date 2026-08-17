defmodule FskickWeb.PlayersLive do
  use FskickWeb, :live_view
  import FskickWeb.Components.PlayerStatsTable

  alias Fskick.Games
  alias Fskick.Players

  @allowed_sorts ~w(points wins games win_ratio)

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(sort: :points)
     |> load_stats()}
  end

  def handle_event("sort", %{"sort" => key}, socket) when key in @allowed_sorts do
    {:noreply,
     socket
     |> assign(:sort, String.to_existing_atom(key))
     |> load_stats()}
  end

  defp load_stats(socket) do
    stats = Players.list_player_stats(sort: socket.assigns.sort)
    assign(socket, stats: stats, games_count: Games.total_games_count())
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <h2 class="text-center text-md md:text-2xl font-bold">Players</h2>
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
