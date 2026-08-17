defmodule Fskick.Users.Password.Plain do
  @moduledoc """
  Test-only `Fskick.Users.Password.Adapter` that prefixes the password instead
  of hashing it, so the suite does not pay for a real KDF.

  Provides **no security whatsoever** — it is wired up in `config/test.exs`
  only. `Fskick.Users.Password.Argon2Test` drives the real hasher directly so
  this fake cannot mask a broken production path.
  """

  @behaviour Fskick.Users.Password.Adapter

  @prefix "plain:"

  @impl true
  def hash(password), do: @prefix <> password

  @impl true
  def valid?(password, hashed_password), do: hash(password) == hashed_password

  @impl true
  def no_user_verify, do: false
end
