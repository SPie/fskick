defmodule FskickWeb.UserForgotPasswordLive do
  use FskickWeb, :live_view

  alias Fskick.Users

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(Users.change_password_reset_request(), as: :user))}
  end

  def handle_event("send", %{"user" => params}, socket) do
    case Users.request_password_reset(params, &url(~p"/users/reset-password/#{&1}")) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "If an account exists for that email, we've sent a link to reset your password."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :user))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <h1 class="text-2xl font-bold text-center mb-2">Forgot your password?</h1>
        <p class="text-sm text-center mb-6">
          Enter your email and we'll send you a link to set a new password.
        </p>

        <.form for={@form} id="forgot_password_form" phx-submit="send">
          <.input field={@form[:email]} type="email" label="Email" autocomplete="username" />

          <div class="mt-4">
            <.button variant="link" phx-disable-with="Sending...">Send reset link</.button>
          </div>
        </.form>

        <p class="text-center text-sm mt-4">
          <.link navigate={~p"/users/log-in"} class="link">Back to log in</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end
end
