defmodule Fskick.GamesTest do
  use Fskick.DataCase, async: false

  alias Fskick.Games
  alias Fskick.Games.Commands.AddPlayerToGame
  alias Fskick.Games.Commands.CreateGame
  alias Fskick.Games.PlayerResult
  alias Fskick.Games.PlayerStats
  alias Fskick.Players
  alias Fskick.Seasons
  alias Fskick.Streaks

  describe "create_game/1" do
    setup do
      unique = System.unique_integer([:positive])
      {:ok, season} = Seasons.create_season("season-#{unique}")
      {:ok, _} = Seasons.activate_season(season.name)
      {:ok, alice} = Players.create_player("Alice-#{unique}")
      {:ok, bob} = Players.create_player("Bob-#{unique}")
      {:ok, carol} = Players.create_player("Carol-#{unique}")
      {:ok, dave} = Players.create_player("Dave-#{unique}")

      %{
        season: season,
        alice: alice,
        bob: bob,
        carol: carol,
        dave: dave
      }
    end

    test "creates a game using the currently-active season", %{
      season: season,
      alice: alice,
      bob: bob,
      carol: carol,
      dave: dave
    } do
      attrs = %{
        team_a_names: [alice.name, bob.name],
        team_b_names: [carol.name, dave.name],
        outcome: :team_a_won
      }

      assert {:ok, %CreateGame{} = command} = Games.create_game(attrs)
      assert command.season_id == season.id
      assert command.outcome == :team_a_won
      assert Enum.sort(command.team_a) == Enum.sort([alice.id, bob.id])
      assert Enum.sort(command.team_b) == Enum.sort([carol.id, dave.id])
    end

    test "accepts a draw outcome", %{alice: alice, carol: carol} do
      attrs = %{
        team_a_names: [alice.name],
        team_b_names: [carol.name],
        outcome: :draw
      }

      assert {:ok, %CreateGame{outcome: :draw}} = Games.create_game(attrs)
    end

    test "uses the supplied played_at when provided", %{alice: alice, carol: carol} do
      played_at = ~U[2026-04-01 00:00:00.000000Z]

      attrs = %{
        team_a_names: [alice.name],
        team_b_names: [carol.name],
        outcome: :team_a_won,
        played_at: played_at
      }

      assert {:ok, %CreateGame{played_at: ^played_at}} = Games.create_game(attrs)
    end

    test "resolves an explicit season name", %{alice: alice, carol: carol} do
      unique = System.unique_integer([:positive])
      {:ok, other_season} = Seasons.create_season("other-#{unique}")

      attrs = %{
        team_a_names: [alice.name],
        team_b_names: [carol.name],
        outcome: :team_a_won,
        season_name: other_season.name
      }

      assert {:ok, %CreateGame{season_id: season_id}} = Games.create_game(attrs)
      assert season_id == other_season.id
    end

    test "returns {:error, {:players_not_found, names}} for unknown player names", %{
      alice: alice
    } do
      attrs = %{
        team_a_names: [alice.name],
        team_b_names: ["Ghost"],
        outcome: :team_a_won
      }

      assert {:error, {:players_not_found, ["Ghost"]}} = Games.create_game(attrs)
    end

    test "returns {:error, {:season_not_found, name}} for unknown season", %{
      alice: alice,
      carol: carol
    } do
      attrs = %{
        team_a_names: [alice.name],
        team_b_names: [carol.name],
        outcome: :team_a_won,
        season_name: "no-such-season"
      }

      assert {:error, {:season_not_found, "no-such-season"}} = Games.create_game(attrs)
    end

    test "returns a changeset error when a player appears in both teams", %{alice: alice} do
      attrs = %{
        team_a_names: [alice.name],
        team_b_names: [alice.name],
        outcome: :team_a_won
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Games.create_game(attrs)
      assert "shares players with team_a" in errors_on(changeset).team_b
    end
  end

  describe "create_game/1 without an active season" do
    test "returns {:error, :no_active_season} when no --season passed and no active season exists" do
      unique = System.unique_integer([:positive])
      {:ok, alice} = Players.create_player("Alice-#{unique}")
      {:ok, carol} = Players.create_player("Carol-#{unique}")

      attrs = %{
        team_a_names: [alice.name],
        team_b_names: [carol.name],
        outcome: :team_a_won
      }

      assert {:error, :no_active_season} = Games.create_game(attrs)
    end
  end

  describe "add_player_to_game/3" do
    setup do
      unique = System.unique_integer([:positive])
      {:ok, season} = Seasons.create_season("season-#{unique}")
      {:ok, _} = Seasons.activate_season(season.name)
      {:ok, alice} = Players.create_player("Alice-#{unique}")
      {:ok, bob} = Players.create_player("Bob-#{unique}")
      {:ok, carol} = Players.create_player("Carol-#{unique}")

      played_at = ~U[2026-04-01 00:00:00.000000Z]

      {:ok, game} =
        Games.create_game(%{
          team_a_names: [alice.name],
          team_b_names: [bob.name],
          outcome: :team_a_won,
          played_at: played_at
        })

      %{
        season: season,
        alice: alice,
        bob: bob,
        carol: carol,
        game: game,
        played_at: played_at
      }
    end

    test "records a player_results row carrying the game's played_at and outcome", %{
      season: season,
      carol: carol,
      game: game,
      played_at: played_at
    } do
      assert {:ok, %AddPlayerToGame{team: :team_a}} =
               Games.add_player_to_game(game.game_id, carol.name, :team_a)

      assert %PlayerResult{team: "a", won: true, season_id: season_id, played_at: ^played_at} =
               Repo.get_by(PlayerResult, player_id: carol.id, game_id: game.game_id)

      assert season_id == season.id
    end

    test "records a loss when the player joins the losing team", %{
      carol: carol,
      game: game
    } do
      assert {:ok, _} = Games.add_player_to_game(game.game_id, carol.name, :team_b)

      assert %PlayerResult{team: "b", won: false} =
               Repo.get_by(PlayerResult, player_id: carol.id, game_id: game.game_id)
    end

    test "bumps player_stats for the game's season", %{
      season: season,
      carol: carol,
      game: game
    } do
      refute Repo.get_by(PlayerStats, season_id: season.id, player_id: carol.id)

      assert {:ok, _} = Games.add_player_to_game(game.game_id, carol.name, :team_a)

      assert %PlayerStats{wins: 1, games: 1} =
               Repo.get_by(PlayerStats, season_id: season.id, player_id: carol.id)
    end

    test "counts a draw as a win, matching the projector's product rule", %{
      season: season,
      alice: alice,
      bob: bob,
      carol: carol
    } do
      {:ok, drawn} =
        Games.create_game(%{
          team_a_names: [alice.name],
          team_b_names: [bob.name],
          outcome: :draw
        })

      assert {:ok, _} = Games.add_player_to_game(drawn.game_id, carol.name, :team_b)

      assert %PlayerResult{won: true} =
               Repo.get_by(PlayerResult, player_id: carol.id, game_id: drawn.game_id)

      assert %PlayerStats{wins: 1, games: 1} =
               Repo.get_by(PlayerStats, season_id: season.id, player_id: carol.id)
    end

    test "does not count a new game", %{season: season, carol: carol, game: game} do
      before_season = Games.season_game_count(season.id)
      before_total = Games.total_games_count()

      assert {:ok, _} = Games.add_player_to_game(game.game_id, carol.name, :team_a)

      assert Games.season_game_count(season.id) == before_season
      assert Games.total_games_count() == before_total
    end

    test "surfaces the added player in teammate and opponent rankings", %{
      alice: alice,
      bob: bob,
      carol: carol,
      game: game
    } do
      assert {:ok, _} = Games.add_player_to_game(game.game_id, carol.name, :team_a)

      assert carol.id in Enum.map(Players.favorite_team(alice.id), & &1.player_id)
      assert carol.id in Enum.map(Players.favorite_opponents(bob.id), & &1.player_id)
      assert alice.id in Enum.map(Players.favorite_team(carol.id), & &1.player_id)
    end

    test "slots the result into the player's streak at the game's position", %{
      alice: alice,
      bob: bob,
      carol: carol,
      game: game
    } do
      # A later game that Carol lost, recorded before she is added to the
      # earlier one — the streak must still order by played_at.
      {:ok, _} =
        Games.create_game(%{
          team_a_names: [alice.name, bob.name],
          team_b_names: [carol.name],
          outcome: :team_a_won,
          played_at: ~U[2026-05-01 00:00:00.000000Z]
        })

      assert Streaks.last_results(carol.id) == [false]

      assert {:ok, _} = Games.add_player_to_game(game.game_id, carol.name, :team_a)

      assert Streaks.last_results(carol.id) == [true, false]
    end

    test "rejects a player who is already in the game", %{
      alice: alice,
      bob: bob,
      carol: carol,
      game: game
    } do
      assert {:error, :already_in_game} =
               Games.add_player_to_game(game.game_id, alice.name, :team_b)

      assert {:error, :already_in_game} =
               Games.add_player_to_game(game.game_id, bob.name, :team_a)

      assert {:ok, _} = Games.add_player_to_game(game.game_id, carol.name, :team_a)

      assert {:error, :already_in_game} =
               Games.add_player_to_game(game.game_id, carol.name, :team_a)
    end

    test "returns {:error, {:game_not_found, id}} for an unknown game", %{carol: carol} do
      id = Ecto.UUID.generate()

      assert {:error, {:game_not_found, ^id}} = Games.add_player_to_game(id, carol.name, :team_a)
    end

    test "returns {:error, {:game_not_found, id}} for a malformed uuid", %{carol: carol} do
      assert {:error, {:game_not_found, "nope"}} =
               Games.add_player_to_game("nope", carol.name, :team_a)
    end

    test "returns {:error, {:player_not_found, name}} for an unknown player", %{game: game} do
      assert {:error, {:player_not_found, "Ghost"}} =
               Games.add_player_to_game(game.game_id, "Ghost", :team_a)
    end

    test "returns a changeset error for an unknown team", %{carol: carol, game: game} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Games.add_player_to_game(game.game_id, carol.name, :team_c)

      assert "is invalid" in errors_on(changeset).team
    end
  end
end
