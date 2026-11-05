defmodule Fskick.Users.Password.Argon2Test do
  @moduledoc """
  Drives the real Argon2 adapter directly, bypassing the configured adapter, so
  the production hashing path stays covered even though the suite runs with
  `Fskick.Users.Password.Plain`.
  """

  use ExUnit.Case, async: true

  alias Fskick.Users.Password

  @password "hello world!"

  test "a hashed password verifies" do
    assert Password.Argon2.valid?(@password, Password.Argon2.hash(@password))
  end

  test "the hash is not the password" do
    hash = Password.Argon2.hash(@password)

    assert String.starts_with?(hash, "$argon2")
    refute hash =~ @password
  end

  test "hashing the same password twice yields different hashes" do
    refute Password.Argon2.hash(@password) == Password.Argon2.hash(@password)
  end

  test "a wrong password does not verify" do
    refute Password.Argon2.valid?("wrong", Password.Argon2.hash(@password))
  end

  test "no_user_verify/0 returns false" do
    refute Password.Argon2.no_user_verify()
  end
end
