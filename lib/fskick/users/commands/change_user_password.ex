defmodule Fskick.Users.Commands.ChangeUserPassword do
  @moduledoc """
  Command to change a user's password.

  Structural validation lives here: presence of all three password fields, that
  the confirmation matches, and that the current password is correct (against
  the read model — the aggregate holds no password hash). The state-dependent
  invariant (the user must exist) lives in the aggregate.

  The plaintext fields exist for validation only: a valid command carries just
  `hashed_password`, so plaintext never reaches the write side.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Fskick.Repo
  alias Fskick.Users.Password
  alias Fskick.Users.User

  @primary_key false
  embedded_schema do
    field :user_id, :binary_id
    field :current_password, :string, redact: true
    field :password, :string, redact: true
    field :password_confirmation, :string, redact: true
    field :hashed_password, :string, redact: true
  end

  @doc """
  Build a validated `%ChangeUserPassword{}` from raw attrs.

  Returns `{:ok, command}` or `{:error, changeset}`.
  """
  def new(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :current_password, :password, :password_confirmation])
    |> validate_required([:user_id, :current_password, :password, :password_confirmation])
    |> validate_password_confirmed()
    |> validate_current_password()
    |> hash_password()
    |> apply_action(:insert)
  end

  # A blank field already has its error; "does not match" on top adds nothing.
  defp validate_password_confirmed(changeset) do
    if Keyword.has_key?(changeset.errors, :password) or
         Keyword.has_key?(changeset.errors, :password_confirmation) do
      changeset
    else
      validate_confirmation(changeset, :password, message: "does not match password")
    end
  end

  defp validate_current_password(changeset) do
    with {:ok, user_id} <- fetch_change(changeset, :user_id),
         {:ok, current_password} <- fetch_change(changeset, :current_password) do
      user = Repo.get(User, user_id)

      if Password.valid?(current_password, user && user.hashed_password) do
        changeset
      else
        add_error(changeset, :current_password, "is not valid")
      end
    else
      :error -> changeset
    end
  end

  defp hash_password(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp hash_password(changeset) do
    changeset
    |> put_change(:hashed_password, Password.hash(get_change(changeset, :password)))
    |> delete_change(:current_password)
    |> delete_change(:password)
    |> delete_change(:password_confirmation)
  end
end
