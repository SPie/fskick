defmodule FskickWeb.UserLoginLive do
  use FskickWeb, :live_view

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email, "password" => nil}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false), temporary_assigns: [form: form]}
  end

  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <h1 class="text-2xl font-bold text-center mb-6">Log in</h1>

        <.form
          for={@form}
          id="login_form"
          action={~p"/users/log-in"}
          phx-submit="submit"
          phx-trigger-action={@trigger_submit}
        >
          <.input field={@form[:email]} type="email" label="Email" autocomplete="username" required />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            required
          />

          <.button variant="primary" phx-disable-with="Logging in..." class="w-full mt-4">
            Log in
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
