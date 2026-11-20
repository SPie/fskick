defmodule FskickWeb.UserResetPasswordLive do
  use FskickWeb, :live_view

  alias Fskick.Users

  @invalid_link "Reset link is invalid or has expired."

  def mount(%{"token" => token}, _session, socket) do
    socket =
      if Users.valid_reset_token?(token) do
        assign(
          socket,
          token: token,
          form: to_form(Users.change_password_reset(), as: :user)
        )
      else
        assign(socket, token: nil, form: nil) |> invalid_link()
      end

    {:ok, socket}
  end

  # Validates on submit only, so the password hasher runs once per attempt.
  def handle_event("reset", %{"user" => params}, socket) do
    case Users.reset_password(socket.assigns.token, params) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset. Please log in.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :user))}

      {:error, :invalid_token} ->
        {:noreply, invalid_link(socket)}

      {:error, _reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Your password could not be reset. Please request a new link and try again."
         )}
    end
  end

  defp invalid_link(socket) do
    socket
    |> put_flash(:error, @invalid_link)
    |> push_navigate(to: ~p"/users/log-in")
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <h1 class="text-2xl font-bold text-center mb-6">Set a new password</h1>

        <%!-- value="" keeps a submitted password out of the re-rendered form. --%>
        <.form :if={@form} for={@form} id="reset_password_form" phx-submit="reset">
          <.input
            field={@form[:password]}
            type="password"
            label="New password"
            value=""
            autocomplete="new-password"
          />
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm new password"
            value=""
            autocomplete="new-password"
          />

          <div class="mt-4">
            <.button variant="link" phx-disable-with="Saving...">Set password</.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
