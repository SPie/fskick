defmodule Fskick.Users.Commands.DeleteUserData do
  @moduledoc """
  Command to erase a user's personal data (right-to-erasure).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :user_id, :binary_id
  end

  @doc """
  Build a validated `%DeleteUserData{}` from raw attrs.

  Returns `{:ok, command}` or `{:error, changeset}`.
  """
  def new(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
    |> apply_action(:insert)
  end
end
