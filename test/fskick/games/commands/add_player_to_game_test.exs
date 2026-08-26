defmodule Fskick.Games.Commands.AddPlayerToGameTest do
  use Fskick.DataCase, async: true

  alias Fskick.Games.Commands.AddPlayerToGame

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        game_id: Ecto.UUID.generate(),
        player_id: Ecto.UUID.generate(),
        team: :team_a
      },
      overrides
    )
  end

  describe "new/1" do
    test "builds a command from valid attrs" do
      attrs = valid_attrs()

      assert {:ok, %AddPlayerToGame{team: :team_a} = command} = AddPlayerToGame.new(attrs)
      assert command.game_id == attrs.game_id
      assert command.player_id == attrs.player_id
    end

    test "accepts team_b" do
      assert {:ok, %AddPlayerToGame{team: :team_b}} =
               AddPlayerToGame.new(valid_attrs(%{team: :team_b}))
    end

    test "requires the game id" do
      assert {:error, changeset} = AddPlayerToGame.new(valid_attrs(%{game_id: nil}))
      assert %{game_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires the player id" do
      assert {:error, changeset} = AddPlayerToGame.new(valid_attrs(%{player_id: nil}))
      assert %{player_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires the team" do
      assert {:error, changeset} = AddPlayerToGame.new(valid_attrs(%{team: nil}))
      assert %{team: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects an unknown team" do
      assert {:error, changeset} = AddPlayerToGame.new(valid_attrs(%{team: :team_c}))
      assert %{team: ["is invalid"]} = errors_on(changeset)
    end
  end
end
