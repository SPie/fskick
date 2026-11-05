defmodule FskickWeb.UserProfileLive do
  use FskickWeb, :live_view

  alias Fskick.Users

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    {:ok, assign(socket, user: user, player: Users.get_linked_player(user))}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <h1 class="text-2xl font-bold mb-6">Profile</h1>

        <dl class="space-y-3">
          <div>
            <dt class="text-sm font-semibold text-gray-400">Email</dt>
            <dd>{@user.email}</dd>
          </div>

          <div>
            <dt class="text-sm font-semibold text-gray-400">Player</dt>
            <dd :if={@player}>
              <.link class="underline" navigate={~p"/players/#{@player.id}"}>{@player.name}</.link>
            </dd>
            <dd :if={is_nil(@player)} class="text-gray-400">No linked player</dd>
          </div>
        </dl>
      </div>
    </Layouts.app>
    """
  end
end
