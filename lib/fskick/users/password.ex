defmodule Fskick.Users.Password do
  @moduledoc """
  Password hashing and verification, and the changeset rules shared by every
  command that takes a new password.

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

  @doc """
  Validate that the changeset's `:password_confirmation` matches `:password`.

  Skipped when either field already has an error: a blank field has its own
  message, and "does not match" on top adds nothing.
  """
  @spec validate_confirmation(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_confirmation(changeset) do
    if Keyword.has_key?(changeset.errors, :password) or
         Keyword.has_key?(changeset.errors, :password_confirmation) do
      changeset
    else
      Ecto.Changeset.validate_confirmation(changeset, :password,
        message: "does not match password"
      )
    end
  end

  @doc """
  Replace the plaintext `:password` and `:password_confirmation` changes of a
  valid changeset with a `:hashed_password`, so plaintext never reaches the
  write side. An invalid changeset is returned unchanged.
  """
  @spec put_hash(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def put_hash(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  def put_hash(changeset) do
    changeset
    |> Ecto.Changeset.put_change(
      :hashed_password,
      hash(Ecto.Changeset.get_change(changeset, :password))
    )
    |> Ecto.Changeset.delete_change(:password)
    |> Ecto.Changeset.delete_change(:password_confirmation)
  end
end
