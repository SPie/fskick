defmodule Fskick.Games.Events.PlayerAddedToGame do
  @derive Jason.Encoder
  defstruct [
    :game_id,
    :player_id,
    :team,
    :season_id,
    :played_at,
    :outcome
  ]
end
