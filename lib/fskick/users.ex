defmodule Fskick.Users do
  @moduledoc """
  Users context.

  Write side dispatches commands through `Fskick.App` (event-sourced); the
  `email` PII is crypto-shredded via a per-user key (`Fskick.Users.Crypto`).
  Read side queries the `Fskick.Users.User` projection.

  Authentication is split across both sides on purpose: the *fact* of a login or
  logout is event-sourced onto the user stream (`UserLoggedIn`, `UserLoggedOut`)
  as audit history, while the session token itself lives in a plain, deletable
  `user_sessions` table whose rows cascade away with the user row on erasure.
  See `Fskick.Users.Session` for why.
  """

  import Ecto.Query, only: [from: 2]

  require Logger

  alias Fskick.App
  alias Fskick.CQRS.Projection
  alias Fskick.Players
  alias Fskick.Repo
  alias Fskick.Users.Commands.DeleteUserData
  alias Fskick.Users.Commands.LogInUser
  alias Fskick.Users.Commands.LogOutUser
  alias Fskick.Users.Commands.RegisterUser
  alias Fskick.Users.Crypto
  alias Fskick.Users.Password
  alias Fskick.Users.Session
  alias Fskick.Users.User

  ## Registration

  @doc """
  Register a user for an existing player.

  Returns `{:ok, %User{}}` on success, or:
  - `{:error, %Ecto.Changeset{}}` when the input is invalid, the email is taken,
    or the player does not exist
  - `{:error, :projection_timeout}` if the read model does not catch up in time
  - `{:error, reason}` for dispatch failures
  """
  def register_user_for_player(player_id, email, password)
      when is_binary(player_id) and is_binary(email) and is_binary(password) do
    user_id = Ecto.UUID.generate()

    attrs = %{
      user_id: user_id,
      player_id: player_id,
      email: email,
      hashed_password: Password.hash(password)
    }

    with {:ok, %RegisterUser{} = command} <- RegisterUser.new(attrs),
         :ok <- Crypto.generate_key(user_id),
         :ok <- App.dispatch(command) do
      Projection.await(User, user_id)
    end
  end

  @doc """
  Create a new player and register a user linked to it, as a single operation.

  Returns the same shapes as `register_user_for_player/3`, plus any error from
  player creation.
  """
  def register_user_with_new_player(player_name, email, password)
      when is_binary(player_name) and is_binary(email) and is_binary(password) do
    with {:ok, player} <- Players.create_player(player_name) do
      register_user_for_player(player.id, email, password)
    end
  end

  ## Read side

  @doc "Fetch a user by id, or `nil` if the id is invalid or unknown."
  def get_user(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get(User, uuid)
      :error -> nil
    end
  end

  @doc "The player linked to a user."
  def get_linked_player(%User{player_id: player_id}), do: Players.get_player(player_id)

  @doc """
  Authenticate by email and password. Returns the `%User{}` on success or
  `nil`. Runs a dummy verification when the email is unknown so response time
  does not reveal whether an account exists.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: normalize_email(email))

    if Password.valid?(password, user && user.hashed_password), do: user
  end

  ## Sessions

  @doc """
  Start a session for `user`: record the login on the user's stream and store
  the session's token hash.

  Returns `{:ok, raw_token}` — the token to put in the session cookie — or
  `{:error, reason}` if the login could not be recorded.

  The dispatch happens *before* the row is inserted, so a usable session can
  never exist without a corresponding audit entry. The reverse failure (an
  audit entry for a login that did not stick) is the harmless one.
  """
  def start_session(%User{} = user) do
    session_id = Ecto.UUID.generate()
    {token, token_hash} = Session.build_token()
    expires_at = Session.expires_at()

    attrs = %{
      user_id: user.id,
      session_id: session_id,
      expires_at: DateTime.to_iso8601(expires_at)
    }

    with {:ok, %LogInUser{} = command} <- LogInUser.new(attrs),
         :ok <- App.dispatch(command) do
      Repo.insert!(%Session{
        id: session_id,
        user_id: user.id,
        token_hash: token_hash,
        expires_at: expires_at
      })

      delete_expired_sessions()

      {:ok, token}
    end
  end

  defp delete_expired_sessions() do
    Repo.delete_all(from s in Session, where: s.expires_at <= ^DateTime.utc_now())
  end

  @doc "The user for a (raw) session token, or `nil` if invalid or expired."
  def get_user_by_session_token(token) when is_binary(token) do
    hash = Session.hash_token(token)
    now = DateTime.utc_now()

    query =
      from s in Session,
        join: u in assoc(s, :user),
        where: s.token_hash == ^hash and s.expires_at > ^now,
        select: u

    Repo.one(query)
  end

  @doc """
  End the session identified by a (raw) session token, and record the logout.

  Always returns `:ok`. The row is deleted *before* the dispatch — the
  security-critical half of logging out is killing the token, so a dispatch
  failure is logged but does not fail the logout. An unknown or already-expired
  token is an idempotent no-op that records nothing.
  """
  def end_session(token) when is_binary(token) do
    case Repo.get_by(Session, token_hash: Session.hash_token(token)) do
      nil ->
        :ok

      %Session{id: session_id, user_id: user_id} = session ->
        Repo.delete!(session)
        record_logout(user_id, session_id)
    end
  end

  defp record_logout(user_id, session_id) do
    with {:ok, %LogOutUser{} = command} <-
           LogOutUser.new(%{user_id: user_id, session_id: session_id}),
         :ok <- App.dispatch(command) do
      :ok
    else
      error ->
        Logger.warning(
          "session #{session_id} was ended but the logout could not be recorded: #{inspect(error)}"
        )

        :ok
    end
  end

  ## Erasure

  @doc """
  Erase a user's personal data (right-to-erasure). Deletes the read-model row
  (session tokens cascade with it) and the crypto key, which makes the email in
  the event store permanently unrecoverable ciphertext. The events themselves
  are retained, and the linked player is left untouched.

  Returns `:ok` or an error tuple.
  """
  def delete_user_data(user_id) when is_binary(user_id) do
    with {:ok, %DeleteUserData{} = command} <- DeleteUserData.new(%{user_id: user_id}),
         :ok <- App.dispatch(command),
         :ok <- Projection.await_absence(User, user_id) do
      Crypto.delete_key(user_id)
      :ok
    end
  end

  defp normalize_email(email), do: email |> String.trim() |> String.downcase()
end
