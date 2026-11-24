defmodule Fskick.Players.Commands.CreatePlayer do
  @moduledoc """
  Command to create a new player.

  Structural validation lives here; the name rules are shared with
  `RenamePlayer` through `Fskick.Players.PlayerName`.
  State-dependent invariants (already created) live in the aggregate.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Fskick.Players.PlayerName

  @primary_key false
  embedded_schema do
    field :player_id, :binary_id
    field :name, :string
  end

  @doc """
  Build a validated `%CreatePlayer{}` from raw attrs.

  Returns `{:ok, command}` or `{:error, changeset}`.
  """
  def new(attrs) do
    attrs
    |> changeset()
    |> validate_required([:player_id])
    |> apply_action(:insert)
  end

  @doc """
  The name rules alone, without the server-generated `player_id`, so a form
  can validate input before anything is dispatched.
  """
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:player_id, :name])
    |> PlayerName.validate()
  end
end
