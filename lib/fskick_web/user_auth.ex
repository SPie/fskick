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

  # Renew the session cookie roughly every two weeks of activity.
  @remember_me_cookie "_fskick_user_remember_me"

  ## Plugs

  @doc """
  Assign `:current_scope` from the session token, if present and valid.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Users.get_user_by_session_token(user_token)
    assign(conn, :current_scope, Scope.for_user(user))
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      {nil, conn}
    end
  end

  ## Login / logout

  @doc """
  Log the user in: store a fresh session token, renew the session to prevent
  fixation, and redirect to the post-login path.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Users.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> Phoenix.Controller.redirect(to: user_return_to || signed_in_path(conn))
    |> then(fn conn -> maybe_write_remember_me(conn, params) end)
  end

  # remember_me is a placeholder for future use; session cookie is enough today.
  defp maybe_write_remember_me(conn, _params), do: conn

  @doc "Log the user out: drop the token and renew the session."
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Users.delete_user_session_token(user_token)

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> Phoenix.Controller.redirect(to: ~p"/")
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp put_token_in_session(conn, token) do
    put_session(conn, :user_token, token)
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
