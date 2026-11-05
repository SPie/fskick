defmodule FskickWeb.UserSessionControllerTest do
  use FskickWeb.ConnCase

  import Fskick.UsersFixtures

  describe "POST /users/log-in" do
    test "logs the user in with valid credentials", %{conn: conn} do
      user = user_fixture(%{email: "alice@example.com", password: "hello world!"})

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => "alice@example.com", "password" => "hello world!"}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # The session now recognises the user on the next request.
      conn = get(conn, ~p"/")
      assert conn.assigns.current_scope.user.id == user.id
    end

    test "rejects invalid credentials", %{conn: conn} do
      user_fixture(%{email: "alice@example.com", password: "hello world!"})

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => "alice@example.com", "password" => "wrong"}
        })

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn} do
      user = user_fixture()
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "succeeds even when no one is logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
    end
  end
end
