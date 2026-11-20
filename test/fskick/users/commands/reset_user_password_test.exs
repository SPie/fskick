defmodule Fskick.Users.Commands.ResetUserPasswordTest do
  use ExUnit.Case, async: true

  import Fskick.DataCase, only: [errors_on: 1]

  alias Fskick.Users.Commands.ResetUserPassword
  alias Fskick.Users.Password

  @attrs %{"password" => "a new password", "password_confirmation" => "a new password"}

  describe "new/2" do
    test "carries the given user id and only the password hash" do
      user_id = Ecto.UUID.generate()

      assert {:ok, command} = ResetUserPassword.new(user_id, @attrs)

      assert command.user_id == user_id
      assert command.hashed_password == Password.hash("a new password")
      assert command.password == nil
      assert command.password_confirmation == nil
    end

    test "ignores a user id submitted with the form" do
      user_id = Ecto.UUID.generate()
      attrs = Map.put(@attrs, "user_id", Ecto.UUID.generate())

      assert {:ok, %ResetUserPassword{user_id: ^user_id}} = ResetUserPassword.new(user_id, attrs)
    end

    test "requires both password fields" do
      assert {:error, changeset} = ResetUserPassword.new(Ecto.UUID.generate(), %{})

      assert %{password: ["can't be blank"], password_confirmation: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "rejects a confirmation that does not match" do
      attrs = %{"password" => "one", "password_confirmation" => "two"}

      assert {:error, changeset} = ResetUserPassword.new(Ecto.UUID.generate(), attrs)
      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end
  end
end
