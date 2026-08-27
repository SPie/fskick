defmodule Fskick.Users.Commands.LogOutUser do
  @moduledoc """
  Command recording that a user ended a session.

  Structural validation lives here: presence of the ids. The state-dependent
  invariant (the user must exist) lives in the aggregate.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :user_id, :binary_id
    field :session_id, :binary_id
  end

  @doc """
  Build a validated `%LogOutUser{}` from raw attrs.

  Returns `{:ok, command}` or `{:error, changeset}`.
  """
  def new(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :session_id])
    |> validate_required([:user_id, :session_id])
    |> apply_action(:insert)
  end
end
