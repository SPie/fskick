defmodule Fskick.Users.Commands.LogInUserTest do
  use ExUnit.Case, async: true

  alias Fskick.Users.Commands.LogInUser

  defp valid_attrs do
    %{
      user_id: Ecto.UUID.generate(),
      session_id: Ecto.UUID.generate(),
      expires_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.to_iso8601()
    }
  end

  test "builds a command from valid attrs" do
    attrs = valid_attrs()

    assert {:ok, %LogInUser{} = command} = LogInUser.new(attrs)
    assert command.user_id == attrs.user_id
    assert command.session_id == attrs.session_id
    assert command.expires_at == attrs.expires_at
  end

  test "rejects missing user_id" do
    assert {:error, changeset} = LogInUser.new(Map.delete(valid_attrs(), :user_id))
    assert {"can't be blank", _} = changeset.errors[:user_id]
  end

  test "rejects missing session_id" do
    assert {:error, changeset} = LogInUser.new(Map.delete(valid_attrs(), :session_id))
    assert {"can't be blank", _} = changeset.errors[:session_id]
  end

  test "rejects missing expires_at" do
    assert {:error, changeset} = LogInUser.new(Map.delete(valid_attrs(), :expires_at))
    assert {"can't be blank", _} = changeset.errors[:expires_at]
  end
end
