defmodule Fskick.Users.Session do
  @moduledoc """
  Session tokens for authentication.

  Deliberately **not** a projection. The *fact* that someone logged in or out is
  event-sourced onto the user's stream (`Fskick.Users.Events.UserLoggedIn` and
  `UserLoggedOut`), but the credential itself lives only here, in a plain
  `user_sessions` table written synchronously by request-handling code. That
  split is intentional:

  - tokens must be deletable, and the event store cannot forget;
  - login stays a single insert rather than a dispatch-and-wait round trip;
  - a read-model rebuild cannot resurrect sessions that were ended;
  - the `users` foreign key still cascades on erasure, which is only safe
    because no projector writes this table.

  The random token is sent to the client (in the signed session cookie); only
  its SHA-256 hash is stored, so a database leak does not expose usable tokens.

  Expiry is **absolute**: `expires_at` is fixed at login and never extended, so
  there is no sliding-window renewal and no expiry event — a lapsed session is a
  deterministic consequence of the timestamp, not a new fact.
  """

  use Ecto.Schema

  @hash_algorithm :sha256
  @rand_size 32

  @session_lifetime_in_days 1

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "user_sessions" do
    field :token_hash, :binary
    field :expires_at, :utc_datetime_usec
    belongs_to :user, Fskick.Users.User

    timestamps(updated_at: false)
  end

  @doc """
  Build a session token and its hashed counterpart. The raw token goes in the
  cookie; the hash is what gets stored.
  """
  def build_token do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, hash_token(token)}
  end

  @doc "Hash a raw session token for storage and lookup."
  def hash_token(token) when is_binary(token), do: :crypto.hash(@hash_algorithm, token)

  @doc "The expiry timestamp for a session starting now."
  def expires_at(now \\ DateTime.utc_now()) do
    DateTime.add(now, @session_lifetime_in_days, :day)
  end

  @doc "How long a session stays valid, in days."
  def lifetime_in_days, do: @session_lifetime_in_days
end
