defmodule Fskick.Games.Aggregates.GameTest do
  use ExUnit.Case, async: true

  alias Fskick.Games.Aggregates.Game
  alias Fskick.Games.Commands.AddPlayerToGame
  alias Fskick.Games.Commands.CreateGame
  alias Fskick.Games.Events.GameCreated
  alias Fskick.Games.Events.PlayerAddedToGame

  describe "execute/2 with CreateGame" do
    test "emits GameCreated when aggregate is uninitialised" do
      cmd = %CreateGame{
        game_id: Ecto.UUID.generate(),
        season_id: Ecto.UUID.generate(),
        played_at: DateTime.utc_now(),
        team_a: [Ecto.UUID.generate(), Ecto.UUID.generate()],
        team_b: [Ecto.UUID.generate()],
        outcome: :team_a_won
      }

      assert %GameCreated{
               game_id: game_id,
               season_id: season_id,
               played_at: played_at,
               team_a: team_a,
               team_b: team_b,
               outcome: "team_a_won"
             } = Game.execute(%Game{}, cmd)

      assert game_id == cmd.game_id
      assert season_id == cmd.season_id
      assert played_at == cmd.played_at
      assert team_a == cmd.team_a
      assert team_b == cmd.team_b
    end

    test "rejects when the game has already been created" do
      state = %Game{game_id: Ecto.UUID.generate()}
      cmd = %CreateGame{game_id: Ecto.UUID.generate()}

      assert {:error, :already_created} = Game.execute(state, cmd)
    end
  end

  describe "execute/2 with AddPlayerToGame" do
    setup do
      alice = Ecto.UUID.generate()
      bob = Ecto.UUID.generate()

      # Build the state the way Commanded does — by replaying the event.
      state =
        Game.apply(%Game{}, %GameCreated{
          game_id: Ecto.UUID.generate(),
          season_id: Ecto.UUID.generate(),
          played_at: ~U[2026-04-01 00:00:00.000000Z],
          team_a: [alice],
          team_b: [bob],
          outcome: "team_a_won"
        })

      %{state: state, alice: alice, bob: bob}
    end

    test "rejects when the game has never been created" do
      cmd = %AddPlayerToGame{
        game_id: Ecto.UUID.generate(),
        player_id: Ecto.UUID.generate(),
        team: :team_a
      }

      assert {:error, :not_found} = Game.execute(%Game{}, cmd)
    end

    test "emits PlayerAddedToGame enriched from aggregate state", %{state: state} do
      player_id = Ecto.UUID.generate()

      cmd = %AddPlayerToGame{game_id: state.game_id, player_id: player_id, team: :team_b}

      assert %PlayerAddedToGame{
               game_id: game_id,
               player_id: ^player_id,
               team: "team_b",
               season_id: season_id,
               played_at: played_at,
               outcome: "team_a_won"
             } = Game.execute(state, cmd)

      assert game_id == state.game_id
      assert season_id == state.season_id
      assert played_at == state.played_at
    end

    test "rejects a player already on team A", %{state: state, alice: alice} do
      cmd = %AddPlayerToGame{game_id: state.game_id, player_id: alice, team: :team_b}

      assert {:error, :already_in_game} = Game.execute(state, cmd)
    end

    test "rejects a player already on team B", %{state: state, bob: bob} do
      cmd = %AddPlayerToGame{game_id: state.game_id, player_id: bob, team: :team_b}

      assert {:error, :already_in_game} = Game.execute(state, cmd)
    end
  end

  describe "apply/2" do
    test "GameCreated sets all fields and indexes both teams into the roster" do
      alice = Ecto.UUID.generate()
      bob = Ecto.UUID.generate()

      event = %GameCreated{
        game_id: Ecto.UUID.generate(),
        season_id: Ecto.UUID.generate(),
        played_at: DateTime.utc_now(),
        team_a: [alice],
        team_b: [bob],
        outcome: "draw"
      }

      assert %Game{
               game_id: game_id,
               season_id: season_id,
               played_at: played_at,
               outcome: "draw",
               roster: roster
             } = Game.apply(%Game{}, event)

      assert game_id == event.game_id
      assert season_id == event.season_id
      assert played_at == event.played_at
      assert roster == %{alice => :team_a, bob => :team_b}
    end

    test "PlayerAddedToGame records the player under the named team" do
      alice = Ecto.UUID.generate()
      added = Ecto.UUID.generate()

      state = %Game{game_id: Ecto.UUID.generate(), outcome: "draw", roster: %{alice => :team_a}}

      # The event's team is a string — its JSON wire format — and is
      # converted back to an atom on the way into the roster.
      assert %Game{roster: %{^alice => :team_a, ^added => :team_b}} =
               Game.apply(state, %PlayerAddedToGame{player_id: added, team: "team_b"})

      assert %Game{roster: %{^alice => :team_a, ^added => :team_a}} =
               Game.apply(state, %PlayerAddedToGame{player_id: added, team: "team_a"})
    end

    test "a player added once is then rejected as already in the game" do
      added = Ecto.UUID.generate()

      state =
        Game.apply(%Game{}, %GameCreated{
          game_id: Ecto.UUID.generate(),
          season_id: Ecto.UUID.generate(),
          played_at: ~U[2026-04-01 00:00:00.000000Z],
          team_a: [Ecto.UUID.generate()],
          team_b: [],
          outcome: "draw"
        })

      cmd = %AddPlayerToGame{game_id: state.game_id, player_id: added, team: :team_b}

      state = Game.apply(state, Game.execute(state, cmd))

      assert {:error, :already_in_game} = Game.execute(state, cmd)
    end
  end
end
