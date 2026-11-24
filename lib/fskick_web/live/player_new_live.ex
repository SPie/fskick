defmodule FskickWeb.PlayerNewLive do
  use FskickWeb, :live_view

  alias Fskick.Players

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(Players.change_new_player(), as: :player))}
  end

  def handle_event("validate", %{"player" => params}, socket) do
    form =
      params
      |> Players.change_new_player()
      |> Map.put(:action, :validate)
      |> to_form(as: :player)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"player" => params}, socket) do
    case Players.create_player(params["name"]) do
      {:ok, player} ->
        {:noreply,
         socket
         |> put_flash(:info, "Player created.")
         |> push_navigate(to: ~p"/players/#{player.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :player))}

      # The event is stored; only the read model has not caught up yet.
      {:error, :projection_timeout} ->
        {:noreply,
         socket
         |> put_flash(:info, "Player created, it may take a moment to appear.")
         |> push_navigate(to: ~p"/players")}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "The player could not be created. Please try again.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <h1 class="text-2xl font-bold mb-6">New player</h1>

        <.form for={@form} id="player_form" phx-change="validate" phx-submit="save">
          <.input field={@form[:name]} type="text" label="Name" phx-debounce="300" />

          <div class="flex gap-2 mt-4">
            <.button variant="link" phx-disable-with="Saving...">Save</.button>
            <.button variant="link" navigate={~p"/players"}>Cancel</.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
