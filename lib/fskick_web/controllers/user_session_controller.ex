defmodule FskickWeb.UserSessionController do
  use FskickWeb, :controller

  alias Fskick.Users
  alias FskickWeb.UserAuth

  @doc """
  Log in with email + password. Cookies can only be written from a plug or
  controller, so the login LiveView submits the form here.
  """
  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Users.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, user_params)
    else
      conn
      |> put_flash(:error, "Invalid email or password")
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
