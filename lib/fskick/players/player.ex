defmodule Fskick.Players.Player do
  @moduledoc """
  Read-model schema for players.

  Written by `Fskick.Players.Projectors.Player` in response to
  `Fskick.Players.Events.PlayerCreated` and
  `Fskick.Players.Events.PlayerRenamed`. Used for queries and
  cross-aggregate uniqueness checks; not used for user input casting.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "players" do
    field :name, :string
    field :created_at, :utc_datetime_usec

    timestamps()
  end
end
