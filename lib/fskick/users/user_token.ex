defmodule Fskick.Users.UserToken do
  @moduledoc """
  Session tokens for authentication. Deliberately **not** event-sourced —
  tokens are ephemeral security state, so they live in a plain `users_tokens`
  table (`Fskick.Repo`), modeled on the Phoenix `phx.gen.auth` token pattern.

  The random token is sent to the client (in the signed session cookie); only
  its SHA-256 hash is stored, so a database leak does not expose usable tokens.
  """

  use Ecto.Schema

  import Ecto.Query

  alias Fskick.Users.UserToken

  @hash_algorithm :sha256
  @rand_size 32

  # Sessions expire after 60 days of inactivity.
  @session_validity_in_days 60

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :user, Fskick.Users.User

    timestamps(updated_at: false)
  end

  @doc """
  Build a session token and its hashed counterpart. The raw token goes in the
  cookie; the returned struct (holding the hash) is stored.
  """
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {token, %UserToken{token: hashed_token, context: "session", user_id: user.id}}
  end

  @doc """
  Query fetching the user tied to a (raw) session token, if still valid.
  """
  def verify_session_token_query(token) do
    hashed_token = :crypto.hash(@hash_algorithm, token)

    query =
      from token in by_token_and_context_query(hashed_token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: user

    {:ok, query}
  end

  @doc "Query for a stored token row by its hash and context."
  def by_token_and_context_query(hashed_token, context) do
    from UserToken, where: [token: ^hashed_token, context: ^context]
  end

  @doc "Query for all tokens belonging to a user (optionally filtered by contexts)."
  def by_user_and_contexts_query(user, :all) do
    from t in UserToken, where: t.user_id == ^user.id
  end

  def by_user_and_contexts_query(user, [_ | _] = contexts) do
    from t in UserToken, where: t.user_id == ^user.id and t.context in ^contexts
  end
end
