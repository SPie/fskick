defmodule Fskick.Games.Game do
  @moduledoc """
  Read-model schema for games.

  Written by `Fskick.Games.Projectors.Game` in response to
  `Fskick.Games.Events.GameCreated`. It is the lookup surface that lets
  the context resolve a game UUID before dispatching commands against
  the `game-<uuid>` aggregate stream; not used for user input casting.

  The roster is deliberately not stored here — per-player rows live in
  `Fskick.Games.PlayerResult`, keyed on `(player_id, game_id)`.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "games" do
    field :season_id, :binary_id
    field :played_at, :utc_datetime_usec
    field :outcome, :string
    field :created_at, :utc_datetime_usec

    timestamps()
  end
end
