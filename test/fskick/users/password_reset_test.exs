defmodule Fskick.Users.PasswordResetTest do
  use Fskick.DataCase

  import Fskick.UsersFixtures

  alias Fskick.Users
  alias Fskick.Users.PasswordResetToken

  @new_password %{
    "password" => "a brand new password",
    "password_confirmation" => "a brand new password"
  }

  defp url(token), do: "https://fskick.test/users/reset-password/#{token}"

  # The email is sent from a Task.Supervisor child; the Swoosh test adapter
  # still delivers it to this process through `$callers`.
  defp request_token(email) do
    assert :ok = Users.request_password_reset(%{"email" => email}, &url/1)
    assert_receive {:email, sent}
    [_, token] = Regex.run(~r{/users/reset-password/([\w-]+)}, sent.text_body)
    {token, sent}
  end

  defp expire_tokens() do
    past = DateTime.add(DateTime.utc_now(), -1, :second)
    Repo.update_all(PasswordResetToken, set: [expires_at: past])
  end

  # Moves the user's tokens out of the throttle window.
  defp age_tokens() do
    long_ago = DateTime.add(DateTime.utc_now(), -PasswordResetToken.throttle_in_seconds() - 1)
    Repo.update_all(PasswordResetToken, set: [inserted_at: long_ago])
  end

  describe "request_password_reset/2" do
    test "emails a link to a known user" do
      user = user_fixture(%{email: "alice@example.com"})

      {token, sent} = request_token("  Alice@Example.com ")

      assert sent.to == [{"", "alice@example.com"}]
      assert sent.from == {"fskick", "noreply@fskick.local"}
      assert sent.text_body =~ url(token)
      assert sent.text_body =~ "10 minutes"
      assert Users.valid_reset_token?(token)
      assert Repo.get_by!(PasswordResetToken, user_id: user.id)
    end

    test "returns :ok and sends nothing for an unknown email" do
      assert :ok = Users.request_password_reset(%{"email" => "nobody@example.com"}, &url/1)
      refute_receive {:email, _}
      assert Repo.aggregate(PasswordResetToken, :count) == 0
    end

    test "rejects a blank email" do
      assert {:error, changeset} = Users.request_password_reset(%{"email" => " "}, &url/1)
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a malformed email" do
      assert {:error, changeset} = Users.request_password_reset(%{"email" => "nope"}, &url/1)
      assert %{email: ["must be a valid email"]} = errors_on(changeset)
    end

    test "sends nothing for a repeat request within the throttle window" do
      user = user_fixture()
      {token, _sent} = request_token(user.email)

      assert :ok = Users.request_password_reset(%{"email" => user.email}, &url/1)
      refute_receive {:email, _}
      assert Users.valid_reset_token?(token)
    end

    test "a new request invalidates the earlier link" do
      user = user_fixture()
      {old_token, _sent} = request_token(user.email)
      age_tokens()

      {new_token, _sent} = request_token(user.email)

      refute Users.valid_reset_token?(old_token)
      assert Users.valid_reset_token?(new_token)
    end

    test "prunes expired tokens of other users" do
      other = user_fixture()
      request_token(other.email)
      expire_tokens()

      request_token(user_fixture().email)

      assert Repo.aggregate(PasswordResetToken, :count) == 1
    end
  end

  describe "valid_reset_token?/1" do
    test "is true for a fresh token, false for a malformed, unknown or expired one" do
      user = user_fixture()
      {token, _sent} = request_token(user.email)

      assert Users.valid_reset_token?(token)

      refute Users.valid_reset_token?("not base64!")
      refute Users.valid_reset_token?(Base.url_encode64("unknown", padding: false))

      expire_tokens()
      refute Users.valid_reset_token?(token)
    end
  end

  describe "reset_password/2" do
    setup do
      user = user_fixture()
      {token, _sent} = request_token(user.email)
      %{user: user, token: token}
    end

    test "sets the new password without logging in", %{user: user, token: token} do
      assert :ok = Users.reset_password(token, @new_password)

      assert Users.get_user_by_email_and_password(user.email, "a brand new password")
      refute Users.get_user_by_email_and_password(user.email, valid_user_password())
      assert Repo.aggregate(Fskick.Users.Session, :count) == 0
    end

    test "a used token cannot be used again", %{token: token} do
      assert :ok = Users.reset_password(token, @new_password)
      assert {:error, :invalid_token} = Users.reset_password(token, @new_password)
    end

    test "rejects an expired token", %{token: token} do
      expire_tokens()
      assert {:error, :invalid_token} = Users.reset_password(token, @new_password)
    end

    test "rejects an unknown token" do
      assert {:error, :invalid_token} = Users.reset_password("bogus", @new_password)
    end

    test "invalid input keeps the token usable", %{token: token} do
      assert {:error, changeset} =
               Users.reset_password(token, %{
                 "password" => "one",
                 "password_confirmation" => "other"
               })

      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)

      assert {:error, changeset} = Users.reset_password(token, %{})

      assert %{password: ["can't be blank"], password_confirmation: ["can't be blank"]} =
               errors_on(changeset)

      assert Users.valid_reset_token?(token)
      assert :ok = Users.reset_password(token, @new_password)
    end
  end
end
