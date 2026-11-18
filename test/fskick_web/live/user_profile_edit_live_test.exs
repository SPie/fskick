defmodule FskickWeb.UserProfileEditLiveTest do
  use FskickWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fskick.UsersFixtures

  alias Fskick.Users

  @password_params %{
    current_password: "hello world!",
    password: "a new password",
    password_confirmation: "a new password"
  }

  defp submit(view, params) do
    view |> form("#profile_form", profile: params) |> render_submit()
  end

  defp submit_and_follow(view, conn, params) do
    {:ok, profile, html} = view |> submit(params) |> follow_redirect(conn, ~p"/users/profile")

    assert html =~ "Profile updated."
    profile
  end

  defp field_error?(view, field, message) do
    has_element?(view, "#profile_form label[for='profile_#{field}'] ~ p", message)
  end

  setup %{conn: conn} do
    user = user_fixture(%{email: "alice@example.com", player_name: "Alice"})
    %{conn: log_in_user(conn, user), user: user}
  end

  describe "edit page" do
    test "redirects anonymous visitors to log in" do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(build_conn(), ~p"/users/profile/edit")
    end

    test "prefills email and player name, not passwords", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      assert has_element?(view, "#profile_email[value='alice@example.com']")
      assert has_element?(view, "#profile_player_name[value='Alice']")

      for field <- [:current_password, :password, :password_confirmation] do
        assert has_element?(view, "#profile_#{field}[type=password][value='']")
      end
    end

    test "has a way back to the profile", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      assert has_element?(view, "a[href='/users/profile']", "Cancel")
    end
  end

  describe "saving" do
    test "shows a new email and player name on the profile", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      profile =
        submit_and_follow(view, conn, %{email: "new@example.com", player_name: "Alicia"})

      assert has_element?(profile, "dd", "new@example.com")
      assert has_element?(profile, "dd a", "Alicia")
    end

    test "changes the password", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      submit_and_follow(view, conn, @password_params)

      assert Users.get_user_by_email_and_password("alice@example.com", "a new password")
      refute Users.get_user_by_email_and_password("alice@example.com", "hello world!")
    end

    test "leaves the password alone when all password fields are empty", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      submit_and_follow(view, conn, %{player_name: "Alicia"})

      assert Users.get_user(user.id).player.name == "Alicia"
      assert Users.get_user_by_email_and_password("alice@example.com", "hello world!")
    end

    test "succeeds without changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      submit_and_follow(view, conn, %{})
    end
  end

  describe "a failure after validation" do
    test "shows the saved profile and asks to check it", %{conn: conn} do
      user = streamless_user_fixture(%{email: "carol@example.com", player_name: "Carol"})
      {:ok, view, _html} = conn |> log_in_streamless(user) |> live(~p"/users/profile/edit")

      submit(view, %{email: "new@example.com", player_name: "Caroline"})

      assert has_element?(view, "#flash-error", "Some of your changes may not have been saved")
      # The email change was never stored, so the form shows the saved one.
      assert has_element?(view, "#profile_email[value='carol@example.com']")
    end

    # `log_in_user/2` records the login on the user's stream, which this user
    # does not have, so store the session row directly.
    defp log_in_streamless(conn, user) do
      {token, token_hash} = Fskick.Users.Session.build_token()

      Fskick.Repo.insert!(%Fskick.Users.Session{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        token_hash: token_hash,
        expires_at: Fskick.Users.Session.expires_at()
      })

      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)
    end
  end

  describe "validation errors" do
    test "rejects a malformed email", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      submit(view, %{email: "nope"})

      assert field_error?(view, :email, "must be a valid email")
      assert Users.get_user(user.id).email == "alice@example.com"
    end

    test "rejects a taken email and player name", %{conn: conn} do
      user_fixture(%{email: "bob@example.com", player_name: "Bob"})
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      submit(view, %{email: "bob@example.com", player_name: "Bob"})

      assert field_error?(view, :email, "has already been taken")
      assert field_error?(view, :player_name, "has already been taken")
    end

    test "rejects a wrong current password", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      submit(view, %{@password_params | current_password: "wrong"})

      assert field_error?(view, :current_password, "is not valid")
      assert Users.get_user_by_email_and_password("alice@example.com", "hello world!")
    end

    test "rejects a mismatched confirmation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      submit(view, %{@password_params | password_confirmation: "other"})

      assert field_error?(view, :password_confirmation, "does not match password")
    end

    test "requires the remaining password fields and saves nothing", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      submit(view, %{player_name: "Alicia", password: "a new password"})

      assert field_error?(view, :current_password, "can't be blank")
      assert field_error?(view, :password_confirmation, "can't be blank")
      assert Users.get_user(user.id).player.name == "Alice"
    end

    test "keeps typed values but never echoes passwords", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/edit")

      html =
        submit(view, %{
          email: "nope",
          current_password: "secret one",
          password: "secret two",
          password_confirmation: "secret three"
        })

      assert has_element?(view, "#profile_email[value='nope']")
      refute html =~ "secret"
    end
  end
end
