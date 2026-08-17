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
end
