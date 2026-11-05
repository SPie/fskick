defmodule FskickWeb.ImprintLive do
  use FskickWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <h1 class="text-2xl font-bold">Impressum</h1>
    </Layouts.app>
    """
  end
end
