defmodule Fskick.Users.PasswordResetToken do
  @moduledoc """
  Single-use tokens for resetting a forgotten password.

  Like `Fskick.Users.Session`, deliberately **not** a projection: a plain
  `user_password_reset_tokens` table written synchronously by request-handling
  code. Tokens are credentials, so they must be deletable (the event store
  cannot forget), and a read-model rebuild must not resurrect used ones. The
  `users` foreign key cascades on erasure, which is only safe because no
  projector writes this table.

  The random token travels only in the emailed link (URL-safe Base64); only its
  SHA-256 hash is stored. A token is valid for ten minutes and is deleted the
  moment it is used, so "used" and "unknown" are indistinguishable by design.
  Requesting a new token deletes the user's earlier ones.
  """

  use Ecto.Schema

  @hash_algorithm :sha256
  @rand_size 32

  @lifetime_in_minutes 10
  @throttle_in_seconds 60

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_password_reset_tokens" do
    field :token_hash, :binary
    field :expires_at, :utc_datetime_usec
    belongs_to :user, Fskick.Users.User

    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  @doc """
  Build a reset token: the URL-safe encoded raw token for the email link, and
  the hash to store.
  """
  def build_token() do
    token = :crypto.strong_rand_bytes(@rand_size)
    {Base.url_encode64(token, padding: false), hash_token(token)}
  end

  @doc """
  Hash an encoded token (as found in the link) for lookup. Returns `:error` when
  the token is not valid URL-safe Base64.
  """
  def hash_encoded(encoded) when is_binary(encoded) do
    case Base.url_decode64(encoded, padding: false) do
      {:ok, token} -> {:ok, hash_token(token)}
      :error -> :error
    end
  end

  defp hash_token(token), do: :crypto.hash(@hash_algorithm, token)

  @doc "The expiry timestamp for a token issued now."
  def expires_at(now \\ DateTime.utc_now()) do
    DateTime.add(now, @lifetime_in_minutes, :minute)
  end

  @doc "How long a token stays valid, in minutes."
  def lifetime_in_minutes(), do: @lifetime_in_minutes

  @doc "Minimum time between two reset emails for the same user, in seconds."
  def throttle_in_seconds(), do: @throttle_in_seconds
end
