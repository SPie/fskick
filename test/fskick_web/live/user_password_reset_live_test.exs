defmodule FskickWeb.UserPasswordResetLiveTest do
  use FskickWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fskick.UsersFixtures

  alias Fskick.Users

  defp request_token(email) do
    :ok = Users.request_password_reset(%{"email" => email}, & &1)
    assert_receive {:email, %{text_body: body}}
    [_, token] = Regex.run(~r{\n\n(\S+)\n\n}, body)
    token
  end

  defp field_error?(view, form, field, message) do
    has_element?(view, "##{form} label[for='user_#{field}'] ~ p", message)
  end

  describe "forgot password page" do
    test "is linked from the log-in page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/log-in")

      assert has_element?(view, "a[href='/users/reset-password']", "Forgot your password?")
    end

    test "redirects authenticated users away", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               conn |> log_in_user(user_fixture()) |> live(~p"/users/reset-password")
    end

    test "sends a reset link for a known email", %{conn: conn} do
      user = user_fixture()
      {:ok, view, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _login, html} =
        view
        |> form("#forgot_password_form", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If an account exists for that email"
      assert_receive {:email, %{text_body: body}}
      assert body =~ url(~p"/users/reset-password") <> "/"
    end

    test "shows the same message for an unknown email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _login, html} =
        view
        |> form("#forgot_password_form", user: %{email: "nobody@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If an account exists for that email"
      refute_receive {:email, _}
    end

    test "shows an error for a malformed email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/reset-password")

      view |> form("#forgot_password_form", user: %{email: "nope"}) |> render_submit()

      assert field_error?(view, "forgot_password_form", :email, "must be a valid email")
    end
  end

  describe "reset password page" do
    setup do
      user = user_fixture()
      %{user: user, token: request_token(user.email)}
    end

    test "sets the new password and sends the user to log in", %{
      conn: conn,
      user: user,
      token: token
    } do
      {:ok, view, _html} = live(conn, ~p"/users/reset-password/#{token}")

      # Landing on the log-in page (which redirects authenticated users away)
      # shows the reset did not log the user in.
      {:ok, _login, html} =
        view
        |> form("#reset_password_form",
          user: %{password: "a new password", password_confirmation: "a new password"}
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Password reset. Please log in."
      assert Users.get_user_by_email_and_password(user.email, "a new password")
    end

    test "shows an error when the confirmation does not match", %{conn: conn, token: token} do
      {:ok, view, _html} = live(conn, ~p"/users/reset-password/#{token}")

      view
      |> form("#reset_password_form", user: %{password: "one", password_confirmation: "two"})
      |> render_submit()

      assert field_error?(view, "reset_password_form", :password_confirmation, "does not match")
    end

    test "redirects with an error for an invalid link", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/users/log-in", flash: flash}}} =
               live(conn, ~p"/users/reset-password/bogus")

      assert flash["error"] == "Reset link is invalid or has expired."
    end

    test "redirects with an error for a used link", %{conn: conn, token: token} do
      :ok = Users.reset_password(token, %{"password" => "x", "password_confirmation" => "x"})

      assert {:error, {:live_redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/users/reset-password/#{token}")
    end
  end
end
