defmodule Fskick.Router do
  use Commanded.Commands.Router

  alias Fskick.Games.Aggregates.Game
  alias Fskick.Games.Commands.AddPlayerToGame
  alias Fskick.Games.Commands.CreateGame
  alias Fskick.Players.Aggregates.Player
  alias Fskick.Players.Commands.CreatePlayer
  alias Fskick.Seasons.Aggregates.Season
  alias Fskick.Seasons.Commands.ActivateSeason
  alias Fskick.Seasons.Commands.CreateSeason
  alias Fskick.Seasons.Commands.DeactivateSeason
  alias Fskick.Users.Aggregates.User
  alias Fskick.Users.Commands.DeleteUserData
  alias Fskick.Users.Commands.RegisterUser

  identify(Player, by: :player_id, prefix: "player-")
  dispatch([CreatePlayer], to: Player)

  identify(Season, by: :season_id, prefix: "season-")
  dispatch([CreateSeason, ActivateSeason, DeactivateSeason], to: Season)

  identify(Game, by: :game_id, prefix: "game-")
  dispatch([CreateGame, AddPlayerToGame], to: Game)

  identify(User, by: :user_id, prefix: "user-")
  dispatch([RegisterUser, DeleteUserData], to: User)
end
