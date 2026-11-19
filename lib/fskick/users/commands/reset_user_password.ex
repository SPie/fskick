defmodule Fskick.Users.Commands.ResetUserPassword do
  @moduledoc """
  Command to set a new password through a password reset link.

  Unlike `Fskick.Users.Commands.ChangeUserPassword` there is no current
  password: possession of a valid reset token, checked by the context before
  dispatch, takes its place. Structural validation lives here (presence, and
  that the confirmation matches); the state-dependent invariant (the user must
  exist) lives in the aggregate.

  The plaintext fields exist for validation only: a valid command carries just
  `hashed_password`, so plaintext never reaches the write side.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Fskick.Users.Password

  @primary_key false
  embedded_schema do
    field :user_id, :binary_id
    field :password, :string, redact: true
    field :password_confirmation, :string, redact: true
    field :hashed_password, :string, redact: true
  end

  @doc """
  Build a validated `%ResetUserPassword{}` for `user_id` from the form's raw
  attrs. `user_id` comes from the reset token, never from the form, so it is
  set programmatically rather than cast.

  Returns `{:ok, command}` or `{:error, changeset}`.
  """
  def new(user_id, attrs) when is_binary(user_id) do
    attrs
    |> changeset()
    |> put_change(:user_id, user_id)
    |> Password.put_hash()
    |> apply_action(:insert)
  end

  @doc "A changeset of the user-entered fields, for rendering the reset form."
  def changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation])
    |> Password.validate_confirmation()
  end
end
