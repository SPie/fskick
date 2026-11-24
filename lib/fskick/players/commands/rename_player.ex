defmodule Fskick.Players.Commands.RenamePlayer do
  @moduledoc """
  Command to rename a player.

  Structural validation lives here; the name rules are shared with
  `CreatePlayer` through `Fskick.Players.PlayerName`, which ignores the
  player's own row when checking availability.
  State-dependent invariants (the player must exist) live in the aggregate.
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
  Build a validated `%RenamePlayer{}` from raw attrs.

  Returns `{:ok, command}` or `{:error, changeset}`.
  """
  def new(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:player_id, :name])
    |> validate_required([:player_id])
    |> PlayerName.validate()
    |> apply_action(:insert)
  end
end
