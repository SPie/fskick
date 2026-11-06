defmodule Fskick.Players.Aggregates.PlayerTest do
  use ExUnit.Case, async: true

  alias Fskick.Players.Aggregates.Player
  alias Fskick.Players.Commands.CreatePlayer
  alias Fskick.Players.Commands.RenamePlayer
  alias Fskick.Players.Events.PlayerCreated
  alias Fskick.Players.Events.PlayerRenamed

  describe "execute/2" do
    test "emits PlayerCreated when aggregate is uninitialised" do
      id = Ecto.UUID.generate()
      cmd = %CreatePlayer{player_id: id, name: "Alice"}

      assert %PlayerCreated{player_id: ^id, name: "Alice"} =
               Player.execute(%Player{}, cmd)
    end

    test "rejects when the player has already been created" do
      state = %Player{player_id: Ecto.UUID.generate(), name: "Alice"}
      cmd = %CreatePlayer{player_id: Ecto.UUID.generate(), name: "Bob"}

      assert {:error, :already_created} = Player.execute(state, cmd)
    end
  end

  describe "execute/2 with RenamePlayer" do
    test "emits PlayerRenamed for a new name" do
      id = Ecto.UUID.generate()
      state = %Player{player_id: id, name: "Alice"}

      assert %PlayerRenamed{player_id: ^id, name: "Alicia"} =
               Player.execute(state, %RenamePlayer{player_id: id, name: "Alicia"})
    end

    test "emits nothing for the current name" do
      id = Ecto.UUID.generate()
      state = %Player{player_id: id, name: "Alice"}

      assert [] = Player.execute(state, %RenamePlayer{player_id: id, name: "Alice"})
    end

    test "rejects an unknown player" do
      assert {:error, :not_found} = Player.execute(%Player{}, %RenamePlayer{name: "Alice"})
    end
  end

  describe "apply/2" do
    test "PlayerRenamed updates the name" do
      id = Ecto.UUID.generate()
      state = %Player{player_id: id, name: "Alice"}

      assert %Player{player_id: ^id, name: "Alicia"} =
               Player.apply(state, %PlayerRenamed{player_id: id, name: "Alicia"})
    end

    test "PlayerCreated sets id and name on the aggregate" do
      id = Ecto.UUID.generate()
      event = %PlayerCreated{player_id: id, name: "Alice"}

      assert %Player{player_id: ^id, name: "Alice"} = Player.apply(%Player{}, event)
    end
  end
end
