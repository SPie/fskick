defmodule FskickWeb.UserProfileLiveTest do
  use FskickWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fskick.UsersFixtures

  alias Fskick.Users

  describe "profile page" do
    test "redirects anonymous visitors to log in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/users/profile")
    end

    test "shows the user's email and linked player", %{conn: conn} do
      user = user_fixture(%{email: "alice@example.com", player_name: "Alice"})
      player = Users.get_linked_player(user)

      {:ok, view, html} = conn |> log_in_user(user) |> live(~p"/users/profile")

      assert html =~ "alice@example.com"
      assert has_element?(view, ~s|a[href="/players/#{player.id}"]|, "Alice")
    end

    test "the nav shows Profile and Log out for authenticated users", %{conn: conn} do
      user = user_fixture()
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/users/profile")

      assert has_element?(view, "a", "Profile")
      assert has_element?(view, "a", "Log out")
    end
  end
end
