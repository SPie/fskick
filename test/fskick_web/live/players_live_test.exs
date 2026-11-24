defmodule FskickWeb.PlayersLiveTest do
  use FskickWeb.ConnCase
  import Phoenix.LiveViewTest

  test "renders the players page with the same column headers", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/players")
    assert html =~ "Players"
    assert html =~ "Pos"
    assert html =~ "Player"
    assert html =~ "Points"
    assert html =~ "Wins"
    assert html =~ "Games"
    assert html =~ "Win Ratio"
  end

  describe "new player link" do
    test "is hidden from anonymous visitors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/players")
      refute has_element?(view, "#new-player")
    end

    test "is shown to logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:ok, view, _html} = live(conn, ~p"/players")
      assert has_element?(view, "#new-player[href='/players/new']")
    end
  end
end
