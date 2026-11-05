defmodule FskickWeb.PlayerDetailLive do
  use FskickWeb, :live_view
  import FskickWeb.Components.PlayerStatsTable
  import FskickWeb.Components.Streak
  import FskickWeb.Components.WinLossToggle

  alias Fskick.Games
  alias Fskick.Players
  alias Fskick.Streaks

  @allowed_sorts ~w(points wins games win_ratio)

  def mount(%{"id" => id}, _session, socket) do
    case Players.get_player(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Player not found")
         |> push_navigate(to: ~p"/players")}

      player ->
        {:ok,
         socket
         |> assign(
           player: player,
           sort: :points,
           fav_sort: :points,
           opp_sort: :points,
           team_outcome: :win,
           opp_outcome: :win
         )
         |> load_stats()
         |> load_streak()
         |> load_favorite_team()
         |> load_favorite_opponents()}
    end
  end

  def handle_event("sort", %{"sort" => key}, socket) when key in @allowed_sorts do
    {:noreply,
     socket
     |> assign(:sort, String.to_existing_atom(key))
     |> load_stats()}
  end

  def handle_event("favorite_sort", %{"sort" => key}, socket) when key in @allowed_sorts do
    {:noreply,
     socket
     |> assign(:fav_sort, String.to_existing_atom(key))
     |> load_favorite_team()}
  end

  def handle_event("opponents_sort", %{"sort" => key}, socket) when key in @allowed_sorts do
    {:noreply,
     socket
     |> assign(:opp_sort, String.to_existing_atom(key))
     |> load_favorite_opponents()}
  end

  def handle_event("toggle_team", _params, socket) do
    {:noreply,
     socket
     |> assign(:team_outcome, flip(socket.assigns.team_outcome))
     |> load_favorite_team()}
  end

  def handle_event("toggle_opponents", _params, socket) do
    {:noreply,
     socket
     |> assign(:opp_outcome, flip(socket.assigns.opp_outcome))
     |> load_favorite_opponents()}
  end

  defp flip(:win), do: :loss
  defp flip(:loss), do: :win

  defp load_stats(socket) do
    player = socket.assigns.player

    stats =
      [sort: socket.assigns.sort]
      |> Players.list_player_stats()
      |> Enum.filter(&(&1.player_id == player.id))

    assign(socket, stats: stats, games_count: Games.total_games_count())
  end

  defp load_streak(socket) do
    player_id = socket.assigns.player.id

    assign(socket,
      last_results: Streaks.last_results(player_id, 5),
      longest_win: Streaks.longest_streak(player_id, :win),
      longest_loss: Streaks.longest_streak(player_id, :loss)
    )
  end

  defp load_favorite_team(socket) do
    player_id = socket.assigns.player.id
    opts = [sort: socket.assigns.fav_sort]

    team =
      case socket.assigns.team_outcome do
        :win -> Players.favorite_team(player_id, opts)
        :loss -> Players.least_favorite_team(player_id, opts)
      end

    assign(socket,
      favorite_team: team,
      target_games: Players.count_player_games(player_id)
    )
  end

  defp load_favorite_opponents(socket) do
    player_id = socket.assigns.player.id
    opts = [sort: socket.assigns.opp_sort]

    opponents =
      case socket.assigns.opp_outcome do
        :win -> Players.favorite_opponents(player_id, opts)
        :loss -> Players.least_favorite_opponents(player_id, opts)
      end

    assign(socket, favorite_opponents: opponents)
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <h2 class="text-center text-md md:text-2xl font-bold">{@player.name}</h2>

      <div class="mx-auto w-4/5">
        <div class="my-5">
          <h3 class="text-left text-sm md:text-xl font-bold">Stats</h3>

          <div>
            <.player_stats_table
              stats={@stats}
              games_count={@games_count}
              sort={@sort}
              highlight_player_id={highlight_id(@current_scope)}
            />
          </div>
        </div>

        <div class="my-5">
          <h3 class="text-left text-sm md:text-xl font-bold">Streak</h3>

          <div class="my-5 flex space-x-4 justify-center">
            <.streak_circles results={@last_results} />
          </div>

          <div class="my-5">
            <h4 class="text-left font-bold">Longest Streaks</h4>

            <div class="my-3 px-6">
              <div class="my-2">{@longest_win} won games</div>
              <div class="my-2">{@longest_loss} lost games</div>
            </div>
          </div>
        </div>

        <div class="my-5">
          <div class="flex items-center space-x-4">
            <h3 class="text-left text-sm md:text-xl font-bold">
              {if @team_outcome == :win, do: "Favorite Team", else: "Worst Team"}
            </h3>

            <.win_loss_toggle checked={@team_outcome == :win} event="toggle_team" />
          </div>

          <div>
            <.player_stats_table
              stats={@favorite_team}
              games_count={@target_games}
              sort={@fav_sort}
              sort_event="favorite_sort"
              count_label={if @team_outcome == :win, do: "Wins", else: "Losses"}
              ratio_label={if @team_outcome == :win, do: "Win Ratio", else: "Loss Ratio"}
              highlight_player_id={highlight_id(@current_scope)}
            />
          </div>
        </div>

        <div class="my-5">
          <div class="flex items-center space-x-4">
            <h3 class="text-left text-sm md:text-xl font-bold">
              {if @opp_outcome == :win, do: "Favorite Opponents", else: "Toughest Opponents"}
            </h3>

            <.win_loss_toggle checked={@opp_outcome == :win} event="toggle_opponents" />
          </div>

          <div>
            <.player_stats_table
              stats={@favorite_opponents}
              games_count={@target_games}
              sort={@opp_sort}
              sort_event="opponents_sort"
              count_label={if @opp_outcome == :win, do: "Wins", else: "Losses"}
              ratio_label={if @opp_outcome == :win, do: "Win Ratio", else: "Loss Ratio"}
              highlight_player_id={highlight_id(@current_scope)}
            />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
