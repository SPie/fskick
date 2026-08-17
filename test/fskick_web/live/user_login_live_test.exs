defmodule FskickWeb.UserLoginLiveTest do
  use FskickWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fskick.UsersFixtures

  describe "log-in page" do
    test "renders the login form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/log-in")
      assert html =~ "Log in"
      assert html =~ "Email"
      assert html =~ "Password"
    end

    test "redirects authenticated users away", %{conn: conn} do
      user = user_fixture()

      assert {:error, {:redirect, %{to: "/"}}} =
               conn |> log_in_user(user) |> live(~p"/users/log-in")
    end
  end

  describe "login navigation" do
    test "the nav shows a Log in link for anonymous visitors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "a", "Log in")
    end
  end
end
