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
      {:ok, token} = Users.start_session(user)

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

  describe "log_in_user/3" do
    setup %{conn: conn} do
      %{conn: Plug.Test.init_test_session(conn, %{})}
    end

    test "stores a working session token and redirects", %{conn: conn} do
      user = user_fixture()

      conn = UserAuth.log_in_user(conn, user)

      assert redirected_to(conn) == "/"
      assert token = get_session(conn, :user_token)
      assert Users.get_user_by_session_token(token).id == user.id
    end

    test "stores a live_socket_id so logout can disconnect LiveViews", %{conn: conn} do
      user = user_fixture()

      conn = UserAuth.log_in_user(conn, user)

      assert "users_sessions:" <> _ = get_session(conn, :live_socket_id)
    end

    test "redirects to the stored return path", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> put_session(:user_return_to, "/players")
        |> UserAuth.log_in_user(user)

      assert redirected_to(conn) == "/players"
    end
  end

  describe "log_out_user/1" do
    setup %{conn: conn} do
      %{conn: Plug.Test.init_test_session(conn, %{})}
    end

    test "invalidates the token and clears the session", %{conn: conn} do
      user = user_fixture()
      {:ok, token} = Users.start_session(user)

      conn =
        conn
        |> put_session(:user_token, token)
        |> UserAuth.log_out_user()

      assert redirected_to(conn) == "/"
      refute get_session(conn, :user_token)
      refute Users.get_user_by_session_token(token)
    end

    test "disconnects LiveViews running on the session", %{conn: conn} do
      live_socket_id = "users_sessions:abc123"
      FskickWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> UserAuth.log_out_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works for a session that is already gone", %{conn: conn} do
      conn = UserAuth.log_out_user(conn)

      assert redirected_to(conn) == "/"
    end
  end

  describe "on_mount :require_authenticated_user" do
    test "continues with a valid session token" do
      user = user_fixture()
      {:ok, token} = Users.start_session(user)

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
      {:ok, token} = Users.start_session(user)

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
