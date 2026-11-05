defmodule Fskick.Users.Password do
  @moduledoc """
  Password hashing and verification.

  The rest of the app talks only to this module; the hashing library itself is
  reached through a `Fskick.Users.Password.Adapter` implementation chosen at
  compile time:

      config :fskick, Fskick.Users.Password,
        adapter: Fskick.Users.Password.Argon2

  """

  @adapter Application.compile_env(
             :fskick,
             [Fskick.Users.Password, :adapter],
             Fskick.Users.Password.Argon2
           )

  @doc "Hash a password for storage."
  @spec hash(String.t()) :: String.t()
  def hash(password) when is_binary(password), do: @adapter.hash(password)

  @doc """
  Verify a password against a stored hash.

  Passing `nil` as the hash — no such user, or a user whose hash was scrubbed
  by erasure — runs a dummy verification before returning `false`, so response
  time does not reveal whether an account exists.
  """
  @spec valid?(String.t(), String.t() | nil) :: boolean()
  def valid?(password, hashed_password)
      when is_binary(password) and is_binary(hashed_password) do
    @adapter.valid?(password, hashed_password)
  end

  def valid?(password, nil) when is_binary(password) do
    @adapter.no_user_verify()
    false
  end
end
