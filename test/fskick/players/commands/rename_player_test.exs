defmodule Fskick.Players.Commands.RenamePlayerTest do
  use Fskick.DataCase, async: true

  alias Fskick.Players.Commands.RenamePlayer
  alias Fskick.Players.Player

  defp insert_player(name) do
    Repo.insert!(%Player{id: Ecto.UUID.generate(), name: name, created_at: DateTime.utc_now()})
  end

  describe "new/1" do
    test "returns a command with valid attrs" do
      id = Ecto.UUID.generate()

      assert {:ok, %RenamePlayer{player_id: ^id, name: "Alice"}} =
               RenamePlayer.new(%{player_id: id, name: "Alice"})
    end

    test "trims surrounding whitespace from name" do
      assert {:ok, %RenamePlayer{name: "Alice"}} =
               RenamePlayer.new(%{player_id: Ecto.UUID.generate(), name: "  Alice  "})
    end

    test "rejects missing player_id" do
      assert {:error, changeset} = RenamePlayer.new(%{name: "Alice"})
      assert "can't be blank" in errors_on(changeset).player_id
    end

    test "rejects a blank name" do
      for name <- [nil, "", "   "] do
        assert {:error, changeset} =
                 RenamePlayer.new(%{player_id: Ecto.UUID.generate(), name: name})

        assert "can't be blank" in errors_on(changeset).name
      end
    end

    test "rejects a name taken by another player" do
      insert_player("Alice")

      assert {:error, changeset} =
               RenamePlayer.new(%{player_id: Ecto.UUID.generate(), name: " Alice "})

      assert "has already been taken" in errors_on(changeset).name
    end

    test "does not treat the player's own name as taken" do
      player = insert_player("Alice")

      assert {:ok, %RenamePlayer{}} = RenamePlayer.new(%{player_id: player.id, name: "Alice"})
    end
  end
end
