defmodule FskickWeb.UserAuthTest do
  use FskickWeb.ConnCase

  import Fskick.UsersFixtures

  alias Fskick.Users
  alias FskickWeb.UserAuth
  alias Phoenix.LiveView

  @socket %LiveView.Socket{endpoint: FskickWeb.Endpoint, assigns: %{__changed__: %{}, flash: %{}}}

  describe "fetch_current_scope_for_user/2" do
    setup %{conn: conn} do
      %{conn: Plug.Test.init_test_session(conn, %{})}
    end

    test "assigns the scope for a valid token", %{conn: conn} do
      user = user_fixture()
      token = Users.generate_user_session_token(user)

      conn =
        conn
        |> put_session(:user_token, token)
        |> UserAuth.fetch_current_scope_for_user([])

      assert conn.assigns.current_scope.user.id == user.id
    end

    test "assigns nil scope without a token", %{conn: conn} do
      conn = UserAuth.fetch_current_scope_for_user(conn, [])
      assert conn.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_authenticated_user" do
    test "continues with a valid session token" do
      user = user_fixture()
      token = Users.generate_user_session_token(user)

      assert {:cont, socket} =
               UserAuth.on_mount(
                 :require_authenticated_user,
                 %{},
                 %{"user_token" => token},
                 @socket
               )

      assert socket.assigns.current_scope.user.id == user.id
    end

    test "halts and redirects without a token" do
      assert {:halt, socket} =
               UserAuth.on_mount(:require_authenticated_user, %{}, %{}, @socket)

      assert socket.redirected == {:redirect, %{to: "/users/log-in", status: 302}}
    end
  end

  describe "on_mount :mount_current_scope" do
    test "assigns nil scope for anonymous sessions" do
      assert {:cont, socket} =
               UserAuth.on_mount(:mount_current_scope, %{}, %{}, @socket)

      assert socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :redirect_if_authenticated" do
    test "redirects an authenticated user" do
      user = user_fixture()
      token = Users.generate_user_session_token(user)

      assert {:halt, socket} =
               UserAuth.on_mount(
                 :redirect_if_authenticated,
                 %{},
                 %{"user_token" => token},
                 @socket
               )

      assert socket.redirected == {:redirect, %{to: "/", status: 302}}
    end
  end
end
