defmodule FskickWeb.UserProfileEditLive do
  use FskickWeb, :live_view

  alias Fskick.Users

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: profile_form(socket.assigns.current_scope.user))}
  end

  # Validates on submit only: a phx-change validation would verify the current
  # password, and so run the password hasher, on every keystroke.
  def handle_event("save", %{"profile" => params}, socket) do
    case Users.update_profile(socket.assigns.current_scope.user, params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated.")
         |> push_navigate(to: ~p"/users/profile")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :profile))}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Some of your changes may not have been saved. The form shows your saved " <>
             "profile; please check it and save again."
         )
         |> assign(form: profile_form(Users.get_user(socket.assigns.current_scope.user.id)))}
    end
  end

  defp profile_form(user) do
    user
    |> Users.change_profile()
    |> to_form(as: :profile)
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <h1 class="text-2xl font-bold mb-6">Edit profile</h1>

        <.form for={@form} id="profile_form" phx-submit="save">
          <.input field={@form[:email]} type="email" label="Email" autocomplete="username" />
          <.input field={@form[:player_name]} type="text" label="Player name" />

          <h2 class="text-lg font-semibold mt-6 mb-1">Change password</h2>
          <p class="text-sm mb-3">Leave these empty to keep your current password.</p>

          <%!-- value="" keeps a submitted password out of the re-rendered form. --%>
          <.input
            field={@form[:current_password]}
            type="password"
            label="Current password"
            value=""
            autocomplete="password"
          />
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

          <div class="flex gap-2 mt-4">
            <.button variant="link" phx-disable-with="Saving...">Save</.button>
            <.button variant="link" navigate={~p"/users/profile"}>Cancel</.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
