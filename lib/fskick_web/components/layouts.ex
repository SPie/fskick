defmodule FskickWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FskickWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders the app layout: FSKick brand header, content slot, footer with
  Imprint link, and the flash group.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    required: true,
    doc: """
    the current authentication scope, or nil for anonymous visitors. Required
    so that a LiveView which forgets to pass it fails at compile time rather
    than silently rendering the logged-out nav to a signed-in user.
    """

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="bg-black text-gray-100">
      <div class="min-h-screen">
        <nav class="bg-gradient-to-b from-gray-900 to-gray-300 via-gray-600">
          <div class="flex items-center">
            <div class="md:px-5 md:py-5 px-3">
              <h1 class="lg:text-5xl text-2xl font-bold">
                <.link navigate={~p"/"}>FSKick</.link>
              </h1>
              <a
                class="text-xs"
                href={Application.get_env(:fskick, :repository_url, "https://github.com/SPie/fskick")}
                target="_blank"
                rel="noopener noreferrer"
              >
                {Application.get_env(:fskick, :version, "dev")}
              </a>
            </div>
            <div class="ml-10 flex items-baseline md:space-x-4 text-sm md:text-xl font-medium w-full">
              <.link navigate={~p"/"} class="pr-3 py-2 rounded-md">Seasons</.link>
              <.link navigate={~p"/players"} class="pr-3 py-2 rounded-md">Players</.link>
              <.link navigate="/streaks" class="pr-3 py-2 rounded-md">Streaks</.link>
            </div>
            <div class="ml-auto flex items-center space-x-3 md:px-5 px-3 text-sm md:text-lg whitespace-nowrap">
              <%= if @current_scope && @current_scope.user do %>
                <.link navigate={~p"/users/profile"} class="py-2 rounded-md">Profile</.link>
                <.link href={~p"/users/log-out"} method="delete" class="py-2 rounded-md">
                  Log out
                </.link>
              <% else %>
                <.link navigate={~p"/users/log-in"} class="py-2 rounded-md">Log in</.link>
              <% end %>
            </div>
          </div>
        </nav>

        <div class="py-2 px-2">
          <div class="mx-auto bg-gradient-to-b from-gray-900 to-gray-300 via-gray-600 p-5 rounded-lg shadow xl:w-1/2 lg:w-3/4 sm:w-11/12 container hover:from-gray-800 hover:to-gray-200 hover:via-gray-500">
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>

      <footer class="text-center text-xs">
        <.link navigate={~p"/imprint"}>Imprint</.link>
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
