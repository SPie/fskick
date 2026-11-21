defmodule Fskick.Players.Commands.RenamePlayer do
  @moduledoc """
  Command to rename a player.

  Structural validation lives here: presence, trimming and name availability
  (checked against the read model, ignoring the player's own row).
  State-dependent invariants (the player must exist) live in the aggregate.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias Fskick.Players.Player
  alias Fskick.Repo

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
    |> update_change(:name, &trim/1)
    |> validate_required([:player_id, :name])
    |> validate_length(:name, max: 50)
    |> validate_name_available()
    |> apply_action(:insert)
  end

  defp validate_name_available(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_name_available(changeset) do
    player_id = get_change(changeset, :player_id)
    name = get_change(changeset, :name)

    if Repo.exists?(from p in Player, where: p.name == ^name and p.id != ^player_id) do
      add_error(changeset, :name, "has already been taken")
    else
      changeset
    end
  end

  defp trim(nil), do: nil
  defp trim(value) when is_binary(value), do: String.trim(value)
end
