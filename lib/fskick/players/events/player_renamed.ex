defmodule Fskick.Players.Events.PlayerRenamed do
  @derive Jason.Encoder
  defstruct [:player_id, :name]
end
