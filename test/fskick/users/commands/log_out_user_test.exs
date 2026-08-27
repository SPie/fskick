defmodule Fskick.Users.Commands.LogOutUserTest do
  use ExUnit.Case, async: true

  alias Fskick.Users.Commands.LogOutUser

  defp valid_attrs do
    %{user_id: Ecto.UUID.generate(), session_id: Ecto.UUID.generate()}
  end

  test "builds a command from valid attrs" do
    attrs = valid_attrs()

    assert {:ok, %LogOutUser{} = command} = LogOutUser.new(attrs)
    assert command.user_id == attrs.user_id
    assert command.session_id == attrs.session_id
  end

  test "rejects missing user_id" do
    assert {:error, changeset} = LogOutUser.new(Map.delete(valid_attrs(), :user_id))
    assert {"can't be blank", _} = changeset.errors[:user_id]
  end

  test "rejects missing session_id" do
    assert {:error, changeset} = LogOutUser.new(Map.delete(valid_attrs(), :session_id))
    assert {"can't be blank", _} = changeset.errors[:session_id]
  end
end
