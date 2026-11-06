defmodule Fskick.Users.Commands.ChangeUserPasswordTest do
  use Fskick.DataCase

  import Fskick.UsersFixtures

  alias Fskick.Users.Commands.ChangeUserPassword
  alias Fskick.Users.Password

  setup do
    %{user: user_fixture()}
  end

  defp attrs(user, overrides \\ %{}) do
    Map.merge(
      %{
        user_id: user.id,
        current_password: valid_user_password(),
        password: "a new password",
        password_confirmation: "a new password"
      },
      overrides
    )
  end

  describe "new/1" do
    test "hashes the new password and drops the plaintext", %{user: user} do
      assert {:ok, %ChangeUserPassword{} = command} = ChangeUserPassword.new(attrs(user))

      assert Password.valid?("a new password", command.hashed_password)
      assert command.current_password == nil
      assert command.password == nil
      assert command.password_confirmation == nil
    end

    test "does not show passwords when inspected", %{user: user} do
      {:error, changeset} = ChangeUserPassword.new(attrs(user, %{current_password: "wrong"}))

      refute inspect(changeset) =~ "a new password"
    end

    test "rejects a wrong current password", %{user: user} do
      assert {:error, changeset} =
               ChangeUserPassword.new(attrs(user, %{current_password: "wrong"}))

      assert "is not valid" in errors_on(changeset).current_password
    end

    test "rejects an unknown user", %{user: user} do
      assert {:error, changeset} =
               ChangeUserPassword.new(attrs(user, %{user_id: Ecto.UUID.generate()}))

      assert "is not valid" in errors_on(changeset).current_password
    end

    test "rejects a confirmation that does not match", %{user: user} do
      assert {:error, changeset} =
               ChangeUserPassword.new(attrs(user, %{password_confirmation: "something else"}))

      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end

    test "reports a wrong current password and a mismatch together", %{user: user} do
      assert {:error, changeset} =
               ChangeUserPassword.new(
                 attrs(user, %{current_password: "wrong", password_confirmation: "other"})
               )

      assert %{
               current_password: ["is not valid"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "requires every password field", %{user: user} do
      for field <- [:current_password, :password, :password_confirmation],
          value <- [nil, "", " "] do
        assert {:error, changeset} = ChangeUserPassword.new(attrs(user, %{field => value}))
        assert errors_on(changeset)[field] == ["can't be blank"]
      end
    end

    test "rejects missing user_id", %{user: user} do
      assert {:error, changeset} = ChangeUserPassword.new(attrs(user, %{user_id: nil}))
      assert "can't be blank" in errors_on(changeset).user_id
    end
  end
end
