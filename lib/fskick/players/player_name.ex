defmodule Fskick.Players.PlayerName do
  @moduledoc """
  The rules for a player name, shared by every command that sets one
  (`CreatePlayer`, `RenamePlayer`): trimmed, present, at most 50
  characters and not used by another player.

  Availability is checked against the read model. The changeset's own
  `player_id`, when set, is excluded so a player keeps its current name
  valid during a rename.
  """

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias Fskick.Players.Player
  alias Fskick.Repo

  @max_length 50

  @doc """
  Trims and validates the `:name` field of `changeset`.
  """
  def validate(%Ecto.Changeset{} = changeset) do
    changeset
    |> update_change(:name, &trim/1)
    |> validate_required([:name])
    |> validate_length(:name, max: @max_length)
    |> validate_available()
  end

  defp validate_available(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_available(changeset) do
    name = get_field(changeset, :name)

    if Repo.exists?(taken_query(name, get_field(changeset, :player_id))) do
      add_error(changeset, :name, "has already been taken")
    else
      changeset
    end
  end

  defp taken_query(name, nil), do: from(p in Player, where: p.name == ^name)

  defp taken_query(name, player_id),
    do: from(p in Player, where: p.name == ^name and p.id != ^player_id)

  defp trim(nil), do: nil
  defp trim(value) when is_binary(value), do: String.trim(value)
end
