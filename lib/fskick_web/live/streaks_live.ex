defmodule FskickWeb.StreaksLive do
  use FskickWeb, :live_view
  import FskickWeb.Components.WinLossToggle

  alias Fskick.Streaks

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       current_type: :win,
       longest_win: Streaks.longest_winning_streak(),
       longest_loss: Streaks.longest_losing_streak()
     )
     |> load_current()}
  end

  def handle_event("toggle_current", _params, socket) do
    next = if socket.assigns.current_type == :win, do: :loss, else: :win

    {:noreply,
     socket
     |> assign(:current_type, next)
     |> load_current()}
  end

  defp load_current(socket) do
    assign(socket, current: Streaks.current_streaks(socket.assigns.current_type, 10))
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <h2 class="text-center text-md md:text-2xl font-bold">Streaks</h2>

      <div class="mx-auto w-4/5">
        <div class="my-5">
          <h3 class="text-left text-sm md:text-xl font-bold">Longest Streaks</h3>

          <div class="my-5 px-6">
            <div class="my-2">
              <.longest_line streak={@longest_win} verb="won" />
            </div>
            <div class="my-2">
              <.longest_line streak={@longest_loss} verb="lost" />
            </div>
          </div>
        </div>

        <div class="my-5">
          <div class="flex items-center space-x-4">
            <h3 class="text-left text-sm md:text-xl font-bold">Current Streaks</h3>

            <.win_loss_toggle checked={@current_type == :win} event="toggle_current" />
          </div>

          <ul class="my-5 px-6">
            <li :for={streak <- @current} class="my-3">
              <.link class="underline" navigate={"/players/" <> streak.player_id}>
                {streak.name}
              </.link>
              {streak.number} games
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :streak, :any, required: true
  attr :verb, :string, required: true

  defp longest_line(%{streak: nil} = assigns) do
    ~H"""
    — 0 <span class="font-bold">{@verb}</span> games
    """
  end

  defp longest_line(assigns) do
    ~H"""
    <.link class="underline" navigate={"/players/" <> @streak.player_id}>
      {@streak.name}
    </.link>
    {@streak.number} <span class="font-bold">{@verb}</span>
    games
    """
  end
end
