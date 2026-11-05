defmodule FskickWeb.UserAuth do
  @moduledoc """
  Authentication plugs and LiveView `on_mount` hooks.

  Sessions are cookie-based: a random session token is stored server-side
  (hashed) and referenced from the signed session cookie. `current_scope`
  (a `Fskick.Users.Scope`, or `nil`) is assigned on every request.
  """

  use FskickWeb, :verified_routes

  import Plug.Conn

  alias Fskick.Users
  alias Fskick.Users.Scope

  ## Plugs

  @doc """
  Assign `:current_scope` from the session token, if present and valid.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    user_token = get_session(conn, :user_token)

    userScope =
      user_token &&
        Users.get_user_by_session_token(user_token)
        |> Scope.for_user()

    assign(conn, :current_scope, userScope)
  end

  ## Login / logout

  @doc """
  Log the user in and redirect.

  Starts a session for `user`, renews the session cookie to prevent fixation,
  and stores the session token in it. A `live_socket_id` is stored alongside
  the token so `log_out_user/1` can tear down any LiveView the session has
  open.
  """
  def log_in_user(conn, user, _params \\ %{}) do
    case Users.start_session(user) do
      {:ok, token} ->
        user_return_to = get_session(conn, :user_return_to)

        conn
        |> renew_session()
        |> put_session(:user_token, token)
        |> put_session(:live_socket_id, live_socket_id(token))
        |> Phoenix.Controller.redirect(to: user_return_to || signed_in_path(conn))

      {:error, _reason} ->
        conn
        |> Phoenix.Controller.put_flash(:error, "Could not sign you in. Please try again.")
        |> Phoenix.Controller.redirect(to: ~p"/users/log-in")
    end
  end

  @doc """
  Log the user out: end the session, disconnect any LiveView still running on
  it, and renew the session cookie.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Users.end_session(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      FskickWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> Phoenix.Controller.redirect(to: ~p"/")
  end

  # Topic a session's LiveView sockets are subscribed to, derived from the token
  # so it is stable for the life of the session without exposing the token.
  defp live_socket_id(token) do
    "users_sessions:" <> Base.url_encode64(:crypto.hash(:sha256, token))
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp signed_in_path(_conn), do: ~p"/"

  ## LiveView on_mount hooks

  @doc """
  `on_mount` callbacks:

  - `:mount_current_scope` — assign `current_scope` for public pages
  - `:require_authenticated_user` — redirect to the login page if anonymous
  - `:redirect_if_authenticated` — redirect signed-in users away (e.g. login)
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated_user, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      user =
        if token = session["user_token"] do
          Users.get_user_by_session_token(token)
        end

      Scope.for_user(user)
    end)
  end
end
