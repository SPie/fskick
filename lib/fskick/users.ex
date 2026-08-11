defmodule Fskick.Users do
  @moduledoc """
  Users context.

  Write side dispatches commands through `Fskick.App` (event-sourced); the
  `email` PII is crypto-shredded via a per-user key (`Fskick.Users.Crypto`).
  Read side queries the `Fskick.Users.User` projection. Authentication tokens
  are kept in a plain, non-event-sourced `users_tokens` table.
  """

  import Ecto.Query, only: [from: 2]

  alias Fskick.App
  alias Fskick.CQRS.Projection
  alias Fskick.Players
  alias Fskick.Repo
  alias Fskick.Users.Commands.DeleteUserData
  alias Fskick.Users.Commands.RegisterUser
  alias Fskick.Users.Crypto
  alias Fskick.Users.Password
  alias Fskick.Users.User
  alias Fskick.Users.UserToken

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

  ## Session tokens

  @doc "Generate a session token, store its hash, and return the raw token."
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc "The user for a (raw) session token, or `nil` if invalid/expired."
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc "Delete a session token."
  def delete_user_session_token(token) do
    hashed_token = :crypto.hash(:sha256, token)
    Repo.delete_all(UserToken.by_token_and_context_query(hashed_token, "session"))
    :ok
  end

  ## Erasure

  @doc """
  Erase a user's personal data (right-to-erasure). Scrubs the read-model row,
  deletes the crypto key (making the email in the event store unrecoverable),
  and removes all session tokens. Events themselves are retained.

  Returns `{:ok, %User{}}` (the scrubbed row) or an error tuple.
  """
  def delete_user_data(user_id) when is_binary(user_id) do
    with {:ok, %DeleteUserData{} = command} <- DeleteUserData.new(%{user_id: user_id}),
         :ok <- App.dispatch(command),
         {:ok, user} <- Projection.await(User, user_id, match: &scrubbed?/1) do
      Crypto.delete_key(user_id)
      Repo.delete_all(from t in UserToken, where: t.user_id == ^user_id)
      {:ok, user}
    end
  end

  defp scrubbed?(%User{email: "deleted-" <> _}), do: true
  defp scrubbed?(_), do: false

  defp normalize_email(email), do: email |> String.trim() |> String.downcase()
end
