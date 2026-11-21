defmodule FskickWeb.PlayerNewLiveTest do
  use FskickWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fskick.Players

  defp field_error?(view, message) do
    has_element?(view, "#player_form label[for='player_name'] ~ p", message)
  end

  test "redirects anonymous visitors to log in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/players/new")
  end

  describe "logged in" do
    setup :register_and_log_in_user

    test "shows a taken name while typing", %{conn: conn} do
      {:ok, _} = Players.create_player("Bob")
      {:ok, view, _html} = live(conn, ~p"/players/new")

      view |> form("#player_form", player: %{name: "Bob"}) |> render_change()

      assert field_error?(view, "has already been taken")
    end

    test "rejects a blank name on submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/players/new")

      view |> form("#player_form", player: %{name: "  "}) |> render_submit()

      assert field_error?(view, "can't be blank")
    end

    test "creates the player and shows its page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/players/new")

      result = view |> form("#player_form", player: %{name: " Bob "}) |> render_submit()

      player = Players.get_player_by_name("Bob")
      assert player
      {:ok, detail, html} = follow_redirect(result, conn, ~p"/players/#{player.id}")
      assert html =~ "Player created."
      assert has_element?(detail, "h2", "Bob")
    end
  end
end
