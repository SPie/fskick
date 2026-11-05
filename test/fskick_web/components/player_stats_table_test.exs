defmodule FskickWeb.Components.PlayerStatsTableTest do
  use FskickWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Fskick.Users.Scope
  alias Fskick.Users.User
  alias FskickWeb.Components.PlayerStatsTable

  defp stat(player_id, name) do
    %{
      player_id: player_id,
      name: name,
      position: 1,
      points: 3.0,
      wins: 1,
      games: 1,
      games_ratio: 100.0,
      win_ratio: 100.0
    }
  end

  describe "highlight_id/1" do
    test "returns the linked player id for a scoped user" do
      scope = %Scope{user: %User{player_id: "player-1"}}
      assert PlayerStatsTable.highlight_id(scope) == "player-1"
    end

    test "returns nil for an anonymous scope" do
      assert PlayerStatsTable.highlight_id(nil) == nil
    end
  end

  describe "player_stats_table/1 highlighting" do
    test "adds the highlight class to the matching row" do
      html =
        render_component(&PlayerStatsTable.player_stats_table/1,
          stats: [stat("abc", "Alice")],
          games_count: 1,
          sort: :points,
          highlight_player_id: "abc"
        )

      assert html =~ "bg-gray-700"
    end

    test "does not highlight when the id does not match" do
      html =
        render_component(&PlayerStatsTable.player_stats_table/1,
          stats: [stat("abc", "Alice")],
          games_count: 1,
          sort: :points,
          highlight_player_id: "other"
        )

      refute html =~ "bg-gray-700"
    end
  end
end
