defmodule Fskick.Users.PasswordTest do
  use ExUnit.Case, async: true

  alias Fskick.Users.Password

  @password "hello world!"

  test "hash/1 delegates to the configured adapter" do
    assert Password.hash(@password) == Password.Plain.hash(@password)
  end

  test "valid?/2 accepts the matching password" do
    assert Password.valid?(@password, Password.hash(@password))
  end

  test "valid?/2 rejects a wrong password" do
    refute Password.valid?("wrong", Password.hash(@password))
  end

  test "valid?/2 rejects a nil hash without raising" do
    refute Password.valid?(@password, nil)
  end

  @types %{
    password: :string,
    password_confirmation: :string,
    hashed_password: :string
  }

  defp changeset(attrs) do
    {%{}, @types}
    |> Ecto.Changeset.cast(attrs, Map.keys(@types))
    |> Ecto.Changeset.validate_required([:password, :password_confirmation])
  end

  describe "validate_confirmation/1" do
    test "accepts a matching confirmation" do
      assert %{valid?: true} =
               Password.validate_confirmation(
                 changeset(%{password: @password, password_confirmation: @password})
               )
    end

    test "rejects a confirmation that does not match" do
      changeset =
        Password.validate_confirmation(
          changeset(%{password: @password, password_confirmation: "other"})
        )

      assert changeset.errors[:password_confirmation] ==
               {"does not match password", [validation: :confirmation]}
    end

    test "adds nothing when a field is already blank" do
      changeset = Password.validate_confirmation(changeset(%{password: @password}))

      assert [password_confirmation: {"can't be blank", _}] = changeset.errors
    end
  end

  describe "put_hash/1" do
    test "replaces the plaintext with a hash on a valid changeset" do
      changeset =
        Password.put_hash(changeset(%{password: @password, password_confirmation: @password}))

      assert changeset.changes == %{hashed_password: Password.hash(@password)}
    end

    test "leaves an invalid changeset unchanged" do
      changeset = changeset(%{password: @password})

      assert Password.put_hash(changeset) == changeset
    end
  end
end
