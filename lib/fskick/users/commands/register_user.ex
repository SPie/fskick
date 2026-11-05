defmodule Fskick.Users.Commands.RegisterUser do
  @moduledoc """
  Command to register a user account for a player.

  Structural validation lives here: presence, email format/normalisation,
  email availability (against the read model), and that the linked player
  exists. State-dependent invariants (already registered) live in the
  aggregate. The password is hashed by the context before building this
  command — only `hashed_password` reaches the write side.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Fskick.Players.Player
  alias Fskick.Repo
  alias Fskick.Users.User

  @email_regex ~r/^[^\s]+@[^\s]+\.[^\s]+$/

  @primary_key false
  embedded_schema do
    field :user_id, :binary_id
    field :player_id, :binary_id
    field :email, :string
    field :hashed_password, :string
  end

  @doc """
  Build a validated `%RegisterUser{}` from raw attrs.

  Returns `{:ok, command}` or `{:error, changeset}`.
  """
  def new(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :player_id, :email, :hashed_password])
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:user_id, :player_id, :email, :hashed_password])
    |> validate_format(:email, @email_regex, message: "must be a valid email")
    |> validate_length(:email, max: 160)
    |> validate_email_available()
    |> validate_player_exists()
    |> apply_action(:insert)
  end

  defp validate_email_available(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_email_available(changeset) do
    case fetch_change(changeset, :email) do
      {:ok, email} ->
        if Repo.get_by(User, email: email) do
          add_error(changeset, :email, "has already been taken")
        else
          changeset
        end

      :error ->
        changeset
    end
  end

  defp validate_player_exists(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_player_exists(changeset) do
    case fetch_change(changeset, :player_id) do
      {:ok, player_id} ->
        if Repo.get(Player, player_id) do
          changeset
        else
          add_error(changeset, :player_id, "does not exist")
        end

      :error ->
        changeset
    end
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(value) when is_binary(value),
    do: value |> String.trim() |> String.downcase()
end
