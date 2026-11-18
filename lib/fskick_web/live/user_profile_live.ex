defmodule FskickWeb.UserProfileLive do
  use FskickWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, user: socket.assigns.current_scope.user)}
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
            <dd>
              <.link class="underline" navigate={~p"/players/#{@user.player.id}"}>
                {@user.player.name}
              </.link>
            </dd>
          </div>
        </dl>

        <div class="mt-6">
          <.button variant="link" navigate={~p"/users/profile/edit"}>Edit profile</.button>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
