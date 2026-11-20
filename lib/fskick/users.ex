defmodule Fskick.Users do
  @moduledoc """
  Users context.

  Write side dispatches commands through `Fskick.App` (event-sourced); the
  `email` PII is crypto-shredded via a per-user key (`Fskick.Users.Crypto`).
  Read side queries the `Fskick.Users.User` projection; every user it returns
  comes with its player preloaded.

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
  alias Fskick.Players.Commands.RenamePlayer
  alias Fskick.Repo
  alias Fskick.Users.Commands.ChangeUserEmail
  alias Fskick.Users.Commands.ChangeUserPassword
  alias Fskick.Users.Commands.DeleteUserData
  alias Fskick.Users.Commands.LogInUser
  alias Fskick.Users.Commands.LogOutUser
  alias Fskick.Users.Commands.RegisterUser
  alias Fskick.Users.Commands.ResetUserPassword
  alias Fskick.Users.Crypto
  alias Fskick.Users.Email
  alias Fskick.Users.Password
  alias Fskick.Users.PasswordResetRequest
  alias Fskick.Users.PasswordResetToken
  alias Fskick.Users.ProfileForm
  alias Fskick.Users.Session
  alias Fskick.Users.User
  alias Fskick.Users.UserNotifier

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
         :ok <- App.dispatch(command),
         {:ok, user} <- Projection.await(User, user_id) do
      {:ok, Repo.preload(user, :player)}
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
      {:ok, uuid} -> User |> Repo.get(uuid) |> Repo.preload(:player)
      :error -> nil
    end
  end

  @doc """
  Authenticate by email and password. Returns the `%User{}` on success or
  `nil`. Runs a dummy verification when the email is unknown so response time
  does not reveal whether an account exists.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: Email.normalize(email))

    if Password.valid?(password, user && user.hashed_password), do: Repo.preload(user, :player)
  end

  ## Profile

  @doc "A changeset for the profile form, for use with `to_form/2`."
  def change_profile(%User{} = user, attrs \\ %{}) do
    ProfileForm.changeset(user, attrs)
  end

  @doc """
  Update a user's email, password and linked player's name.

  Everything is validated before anything is dispatched, and only what changed
  is dispatched. All commands are dispatched before any projection is awaited,
  so a lagging read model never holds back the remaining changes.

  The changes span two aggregates, so they are not atomic: a dispatch failure
  part-way keeps the changes already dispatched, and a projection timeout means
  the change is stored but not visible yet. Repeating the update is safe,
  because changes already applied no longer count as changes.

  Returns `{:ok, %User{}}` on success, or:
  - `{:error, %Ecto.Changeset{}}` when the input is invalid
  - `{:error, :projection_timeout}` if the read model does not catch up in time
  - `{:error, reason}` for dispatch failures
  """
  def update_profile(%User{id: user_id}, attrs) do
    user = get_user(user_id)

    with {:ok, commands} <- ProfileForm.commands(user, attrs),
         :ok <- each_until_error(commands, &App.dispatch/1),
         :ok <- each_until_error(commands, &await_profile_projection/1) do
      {:ok, get_user(user_id)}
    end
  end

  defp each_until_error(commands, fun) do
    Enum.reduce_while(commands, :ok, fn command, :ok ->
      case fun.(command) do
        :ok -> {:cont, :ok}
        {:ok, _struct} -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp await_profile_projection(%RenamePlayer{} = command), do: Players.await_renamed(command)

  defp await_profile_projection(%ChangeUserEmail{user_id: user_id, email: email}) do
    Projection.await(User, user_id, match: &(&1.email == email))
  end

  defp await_profile_projection(%ChangeUserPassword{user_id: user_id} = command) do
    Projection.await(User, user_id, match: &(&1.hashed_password == command.hashed_password))
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

    query |> Repo.one() |> Repo.preload(:player)
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

  ## Password reset

  @doc "A changeset for the forgot-password form, for use with `to_form/2`."
  def change_password_reset_request(attrs \\ %{}) do
    PasswordResetRequest.changeset(attrs)
  end

  @doc """
  Request a password reset link for the email in `attrs`.

  When a user has that email, a fresh token replaces their earlier ones and the
  link — built by `url_fun` from the encoded token — is emailed in the
  background. Unknown addresses, and repeat requests within the throttle
  window, quietly send nothing. Neither the result nor the response time says
  whether an account exists.

  Returns `:ok` for any well-formed email, or `{:error, %Ecto.Changeset{}}` when
  the email is blank or malformed.
  """
  def request_password_reset(attrs, url_fun) when is_function(url_fun, 1) do
    with {:ok, %PasswordResetRequest{email: email}} <- PasswordResetRequest.new(attrs) do
      case Repo.get_by(User, email: email) do
        nil -> :ok
        %User{} = user -> send_password_reset(user, url_fun)
      end
    end
  end

  defp send_password_reset(%User{id: user_id} = user, url_fun) do
    now = DateTime.utc_now()

    if not password_reset_throttled?(user_id, now) do
      {token, token_hash} = PasswordResetToken.build_token()

      # Only the newest link works: the user's earlier tokens go, and lapsed
      # tokens of anyone are pruned along the way (no sweeper process).
      Repo.delete_all(
        from t in PasswordResetToken, where: t.user_id == ^user_id or t.expires_at <= ^now
      )

      Repo.insert!(%PasswordResetToken{
        user_id: user_id,
        token_hash: token_hash,
        expires_at: PasswordResetToken.expires_at(now)
      })

      {:ok, _pid} =
        Task.Supervisor.start_child(Fskick.TaskSupervisor, fn ->
          UserNotifier.deliver_reset_password_instructions(user, url_fun.(token))
        end)
    end

    :ok
  end

  defp password_reset_throttled?(user_id, now) do
    since = DateTime.add(now, -PasswordResetToken.throttle_in_seconds(), :second)

    Repo.exists?(
      from t in PasswordResetToken, where: t.user_id == ^user_id and t.inserted_at > ^since
    )
  end

  @doc """
  Whether a (URL-encoded) reset token can still be used: `false` if it is
  malformed, unknown, used or expired.
  """
  def valid_reset_token?(token) when is_binary(token) do
    reset_token_user_id(token) != nil
  end

  # The id of the user a valid reset token belongs to, or `nil`. The foreign key
  # cascades on erasure, so a token row always has its user.
  defp reset_token_user_id(token) do
    with {:ok, token_hash} <- PasswordResetToken.hash_encoded(token) do
      now = DateTime.utc_now()

      Repo.one(
        from t in PasswordResetToken,
          where: t.token_hash == ^token_hash and t.expires_at > ^now,
          select: t.user_id
      )
    else
      :error -> nil
    end
  end

  @doc "A changeset for the new-password form, for use with `to_form/2`."
  def change_password_reset(attrs \\ %{}) do
    ResetUserPassword.changeset(attrs)
  end

  @doc """
  Set a new password through a (URL-encoded) reset token. Does not log the user
  in.

  The input is validated before the token is touched, so a typo keeps the link
  usable. The token is then consumed with a single delete, so of two concurrent
  submits only one gets through; a dispatch failure after that point means the
  user has to request a new link.

  Returns `:ok` on success, or:
  - `{:error, :invalid_token}` when the token is malformed, unknown, used or
    expired
  - `{:error, %Ecto.Changeset{}}` when the input is invalid
  - `{:error, :projection_timeout}` if the read model does not catch up in time
  - `{:error, reason}` for dispatch failures
  """
  def reset_password(token, attrs) when is_binary(token) and is_map(attrs) do
    with user_id when is_binary(user_id) <- reset_token_user_id(token) || {:error, :invalid_token},
         {:ok, %ResetUserPassword{} = command} <- ResetUserPassword.new(user_id, attrs),
         :ok <- consume_reset_token(token, user_id),
         :ok <- App.dispatch(command),
         {:ok, _user} <-
           Projection.await(User, user_id,
             match: &(&1.hashed_password == command.hashed_password)
           ) do
      :ok
    end
  end

  defp consume_reset_token(token, user_id) do
    {:ok, token_hash} = PasswordResetToken.hash_encoded(token)
    now = DateTime.utc_now()

    case Repo.delete_all(
           from t in PasswordResetToken,
             where: t.token_hash == ^token_hash and t.expires_at > ^now
         ) do
      {1, _} ->
        Repo.delete_all(from t in PasswordResetToken, where: t.user_id == ^user_id)
        :ok

      {0, _} ->
        {:error, :invalid_token}
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
end
