defmodule Fskick.Players.Commands.CreatePlayer do
  @moduledoc """
  Command to create a new player.

  Structural validation lives here: presence, trimming, non-empty name,
  and name availability (checked against the read model).
  State-dependent invariants (already created) live in the aggregate.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Fskick.Players.Player
  alias Fskick.Repo

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
    |> update_change(:name, &trim/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_name_available()
  end

  defp validate_name_available(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_name_available(changeset) do
    case fetch_change(changeset, :name) do
      {:ok, name} ->
        if Repo.get_by(Player, name: name) do
          add_error(changeset, :name, "has already been taken")
        else
          changeset
        end

      :error ->
        changeset
    end
  end

  defp trim(nil), do: nil
  defp trim(value) when is_binary(value), do: String.trim(value)
end
