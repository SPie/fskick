defmodule Fskick.PlayersTest do
  use Fskick.DataCase, async: false

  alias Fskick.Games
  alias Fskick.Games.PlayerResult
  alias Fskick.Players
  alias Fskick.Players.Player
  alias Fskick.Players.PlayerStat
  alias Fskick.Seasons

  describe "create_player/1" do
    test "creates a player and projects it to the read model" do
      assert {:ok, %Player{name: "Alice", id: id}} = Players.create_player("Alice")
      assert is_binary(id)
      assert Players.get_player_by_name("Alice")
    end

    test "trims surrounding whitespace from the name" do
      assert {:ok, %Player{name: "Alice"}} = Players.create_player("  Alice  ")
    end

    test "rejects duplicate names" do
      assert {:ok, _} = Players.create_player("Alice")
      assert {:error, %Ecto.Changeset{} = changeset} = Players.create_player("Alice")
      assert "has already been taken" in errors_on(changeset).name
    end

    test "rejects duplicate names after trimming" do
      assert {:ok, _} = Players.create_player("Alice")
      assert {:error, %Ecto.Changeset{} = changeset} = Players.create_player("  Alice  ")
      assert "has already been taken" in errors_on(changeset).name
    end

    test "rejects blank name" do
      assert {:error, %Ecto.Changeset{}} = Players.create_player("")
      assert {:error, %Ecto.Changeset{}} = Players.create_player("   ")
    end

    test "rejects names longer than 50 characters" do
      assert {:ok, _} = Players.create_player(String.duplicate("a", 50))

      assert {:error, %Ecto.Changeset{} = changeset} =
               Players.create_player(String.duplicate("a", 51))

      assert "should be at most 50 character(s)" in errors_on(changeset).name
    end
  end

  describe "change_new_player/1" do
    test "is valid for an available name" do
      assert Players.change_new_player(%{"name" => "Alice"}).valid?
    end

    test "reports a blank name" do
      assert "can't be blank" in errors_on(Players.change_new_player(%{"name" => " "})).name
    end

    test "reports a taken name" do
      assert {:ok, _} = Players.create_player("Alice")
      changeset = Players.change_new_player(%{"name" => "Alice"})
      assert "has already been taken" in errors_on(changeset).name
    end
  end

  describe "favorite_team/2" do
    setup do
      unique = System.unique_integer([:positive])
      {:ok, season} = Seasons.create_season("season-#{unique}")
      {:ok, _} = Seasons.activate_season(season.name)
      {:ok, alice} = Players.create_player("Alice-#{unique}")
      {:ok, b1} = Players.create_player("B1-#{unique}")
      {:ok, b2} = Players.create_player("B2-#{unique}")
      {:ok, b3} = Players.create_player("B3-#{unique}")
      {:ok, t3} = Players.create_player("T3-#{unique}")
      {:ok, t4} = Players.create_player("T4-#{unique}")
      {:ok, t5} = Players.create_player("T5-#{unique}")

      baseline = Repo.aggregate(PlayerResult, :count)

      # b1 with alice: 2W/3G → 67%
      create_game!([alice, b1], [b2, b3], :team_a_won, ~U[2026-03-01 12:00:00.000000Z])
      create_game!([alice, b1], [b2, b3], :team_a_won, ~U[2026-03-02 12:00:00.000000Z])
      # b2 with alice (g3): 1W start
      create_game!([alice, b2], [b1, b3], :team_a_won, ~U[2026-03-03 12:00:00.000000Z])
      # b1, b2 both with alice; team_b wins → b1, b2 each get a loss with alice
      create_game!([alice, b1, b2], [b3, t3], :team_b_won, ~U[2026-03-04 12:00:00.000000Z])
      # b2 with alice loses → b2: 1W/3G total = 33%
      create_game!([alice, b2], [b1, b3], :team_b_won, ~U[2026-03-05 12:00:00.000000Z])
      # t3 with alice loses → 0W/1G = 0%
      create_game!([alice, t3], [b1, b2], :team_b_won, ~U[2026-03-06 12:00:00.000000Z])
      # t4 with alice wins → 1W/1G = 100%
      create_game!([alice, t4], [b1, b2], :team_a_won, ~U[2026-03-07 12:00:00.000000Z])
      # t5 with alice wins → 1W/1G = 100%
      create_game!([alice, t5], [b1, b2], :team_a_won, ~U[2026-03-08 12:00:00.000000Z])

      # 7 games × 4 players + 1 game × 5 players = 33 player_results rows.
      await_results(baseline + 33)

      %{
        alice: alice,
        b1: b1,
        b2: b2,
        b3: b3,
        t3: t3,
        t4: t4,
        t5: t5
      }
    end

    test "excludes opponents — b3 never appears (was always on the other team)", %{
      alice: alice,
      b3: b3
    } do
      result = Players.favorite_team(alice.id, sort: :wins, limit: 10)
      refute Enum.any?(result, &(&1.player_id == b3.id))
    end

    test "excludes the target player themselves", %{alice: alice} do
      result = Players.favorite_team(alice.id, sort: :wins, limit: 10)
      refute Enum.any?(result, &(&1.player_id == alice.id))
    end

    test "aggregates wins and games over shared-team games only", %{alice: alice, b1: b1} do
      result = Players.favorite_team(alice.id, sort: :wins, limit: 10)
      b1_stat = Enum.find(result, &(&1.player_id == b1.id))
      assert %PlayerStat{wins: 2, games: 3} = b1_stat
    end

    test "default sort is :points, default limit is 5", %{alice: alice} do
      result = Players.favorite_team(alice.id)
      assert length(result) == 5
      assert Enum.sort_by(result, & &1.points, :desc) == result
    end

    test "limit caps the result", %{alice: alice} do
      result = Players.favorite_team(alice.id, sort: :wins, limit: 3)
      assert length(result) == 3
    end

    test "sorting by :wins ranks b1 first (most shared wins)", %{alice: alice, b1: b1} do
      assert [%PlayerStat{player_id: id, wins: 2} | _] =
               Players.favorite_team(alice.id, sort: :wins, limit: 5)

      assert id == b1.id
    end

    test "sorting by :win_ratio ranks 100% players (t4, t5) above 67% (b1)", %{
      alice: alice,
      t4: t4,
      t5: t5,
      b1: b1
    } do
      [first, second, third | _] = Players.favorite_team(alice.id, sort: :win_ratio, limit: 5)
      assert MapSet.new([first.player_id, second.player_id]) == MapSet.new([t4.id, t5.id])
      assert third.player_id == b1.id
    end

    test "top-N membership follows the sort (:wins vs :win_ratio differ at limit=3)", %{
      alice: alice,
      b2: b2,
      t4: t4,
      t5: t5
    } do
      by_wins = MapSet.new(Players.favorite_team(alice.id, sort: :wins, limit: 3), & &1.player_id)

      by_ratio =
        MapSet.new(Players.favorite_team(alice.id, sort: :win_ratio, limit: 3), & &1.player_id)

      # b1 (the 2W player) is in both — it dominates either way.
      # By wins: b2 is the next-highest with 1W/3G, edging out t4 and t5 on the
      # games tiebreaker — so b2 is included.
      assert b2.id in by_wins
      # By win_ratio: t4 and t5 (both 100%) edge out b2 — b2 drops out.
      refute b2.id in by_ratio
      # Conversely, t4 and t5 are in the win_ratio top-3 but absent from the
      # wins top-3.
      assert MapSet.subset?(MapSet.new([t4.id, t5.id]), by_ratio)
    end

    test "returns [] for a player with no games" do
      {:ok, ghost} = Players.create_player("Ghost-#{System.unique_integer([:positive])}")
      assert Players.favorite_team(ghost.id) == []
    end

    test "games_ratio uses the target's own total games as denominator", %{
      alice: alice,
      b1: b1
    } do
      result = Players.favorite_team(alice.id, sort: :wins, limit: 10)
      b1_stat = Enum.find(result, &(&1.player_id == b1.id))
      # Alice played 8 games total; b1 shared the team in 3.
      # games_ratio is in percent — 3/8 * 100 = 37.5
      assert_in_delta b1_stat.games_ratio, 37.5, 0.01
    end
  end

  describe "favorite_opponents/2" do
    setup do
      unique = System.unique_integer([:positive])
      {:ok, season} = Seasons.create_season("season-#{unique}")
      {:ok, _} = Seasons.activate_season(season.name)
      {:ok, alice} = Players.create_player("Alice-#{unique}")
      {:ok, b1} = Players.create_player("B1-#{unique}")
      {:ok, opp_a} = Players.create_player("OppA-#{unique}")
      {:ok, opp_b} = Players.create_player("OppB-#{unique}")
      {:ok, opp_c} = Players.create_player("OppC-#{unique}")
      {:ok, opp_d} = Players.create_player("OppD-#{unique}")
      {:ok, opp_e} = Players.create_player("OppE-#{unique}")

      baseline = Repo.aggregate(PlayerResult, :count)

      # opp_a: 1 strict win-against (g1), 1 strict loss-against (g2), 1 draw (g3) → 1W/3G = 33%
      create_game!([alice, b1], [opp_a, opp_b], :team_a_won, ~U[2026-04-01 12:00:00.000000Z])
      create_game!([alice], [opp_a], :team_b_won, ~U[2026-04-02 12:00:00.000000Z])
      create_game!([alice], [opp_a], :draw, ~U[2026-04-03 12:00:00.000000Z])
      # opp_c: 1W/1G = 100%
      create_game!([alice], [opp_c], :team_a_won, ~U[2026-04-04 12:00:00.000000Z])
      # opp_d, opp_e: each 1W/1G = 100%
      create_game!([alice, b1], [opp_d, opp_e], :team_a_won, ~U[2026-04-05 12:00:00.000000Z])
      # opp_b: a second game-against, also strictly won → 2W/2G = 100%
      create_game!([alice], [opp_b], :team_a_won, ~U[2026-04-06 12:00:00.000000Z])

      # Row count: 4 + 2 + 2 + 2 + 4 + 2 = 16
      await_results(baseline + 16)

      %{
        alice: alice,
        b1: b1,
        opp_a: opp_a,
        opp_b: opp_b,
        opp_c: opp_c,
        opp_d: opp_d,
        opp_e: opp_e
      }
    end

    test "excludes teammates — b1 never opposed alice, so does not appear", %{
      alice: alice,
      b1: b1
    } do
      result = Players.favorite_opponents(alice.id, sort: :wins, limit: 10)
      refute Enum.any?(result, &(&1.player_id == b1.id))
    end

    test "excludes the target themselves", %{alice: alice} do
      result = Players.favorite_opponents(alice.id, sort: :wins, limit: 10)
      refute Enum.any?(result, &(&1.player_id == alice.id))
    end

    test "draws count as games-against but NOT as wins-against", %{alice: alice, opp_a: opp_a} do
      result = Players.favorite_opponents(alice.id, sort: :wins, limit: 10)
      stat = Enum.find(result, &(&1.player_id == opp_a.id))
      assert %PlayerStat{wins: 1, games: 3} = stat
      # win_ratio is wins / games — draws drag it down.
      assert_in_delta stat.win_ratio, 100 / 3, 0.01
    end

    test "default sort is :points, default limit is 5", %{alice: alice} do
      result = Players.favorite_opponents(alice.id)
      assert length(result) == 5
      assert Enum.sort_by(result, & &1.points, :desc) == result
    end

    test "sorting by :wins ranks opp_b first (2 strict wins against)", %{
      alice: alice,
      opp_b: opp_b
    } do
      assert [%PlayerStat{player_id: id, wins: 2} | _] =
               Players.favorite_opponents(alice.id, sort: :wins, limit: 5)

      assert id == opp_b.id
    end

    test "top-3 by :win_ratio drops opp_a (33% ratio) but :wins keeps them", %{
      alice: alice,
      opp_a: opp_a,
      opp_b: opp_b
    } do
      by_wins =
        MapSet.new(Players.favorite_opponents(alice.id, sort: :wins, limit: 3), & &1.player_id)

      by_ratio =
        MapSet.new(
          Players.favorite_opponents(alice.id, sort: :win_ratio, limit: 3),
          & &1.player_id
        )

      # opp_b (2W/2G = 100%) tops both rankings.
      assert opp_b.id in by_wins
      assert opp_b.id in by_ratio
      # By wins, opp_a (1W/3G) edges 100% one-game players on the `games`
      # tiebreaker, so opp_a is included.
      assert opp_a.id in by_wins
      # By win_ratio, opp_a (33%) is the worst opponent — drops out of top-3.
      refute opp_a.id in by_ratio
    end

    test "returns [] for a player with no games" do
      {:ok, ghost} = Players.create_player("Ghost-#{System.unique_integer([:positive])}")
      assert Players.favorite_opponents(ghost.id) == []
    end

    test "games_ratio uses the target's own total games as denominator", %{
      alice: alice,
      opp_b: opp_b
    } do
      result = Players.favorite_opponents(alice.id, sort: :wins, limit: 10)
      stat = Enum.find(result, &(&1.player_id == opp_b.id))
      # Alice played 6 games total; opp_b was opponent in 2 → 2/6 * 100 = 33.33
      assert_in_delta stat.games_ratio, 100 / 3, 0.01
    end
  end

  describe "least_favorite_team/2" do
    setup do
      unique = System.unique_integer([:positive])
      {:ok, season} = Seasons.create_season("season-#{unique}")
      {:ok, _} = Seasons.activate_season(season.name)
      {:ok, alice} = Players.create_player("Alice-#{unique}")
      {:ok, t1} = Players.create_player("T1-#{unique}")
      {:ok, t2} = Players.create_player("T2-#{unique}")
      {:ok, t3} = Players.create_player("T3-#{unique}")
      {:ok, t4} = Players.create_player("T4-#{unique}")
      {:ok, t5} = Players.create_player("T5-#{unique}")
      {:ok, o1} = Players.create_player("O1-#{unique}")
      {:ok, o2} = Players.create_player("O2-#{unique}")

      baseline = Repo.aggregate(PlayerResult, :count)

      # t1 with alice: lost g1+g2, won g3 → 2 losses / 3 games
      create_game!([alice, t1], [o1, o2], :team_b_won, ~U[2026-05-01 12:00:00.000000Z])
      create_game!([alice, t1], [o1, o2], :team_b_won, ~U[2026-05-02 12:00:00.000000Z])
      create_game!([alice, t1], [o1, o2], :team_a_won, ~U[2026-05-03 12:00:00.000000Z])
      # t2 with alice: lost g4, drew g7 → 1 loss / 2 games (draw is not a loss)
      create_game!([alice, t2], [o1, o2], :team_b_won, ~U[2026-05-04 12:00:00.000000Z])
      # t3, t4 with alice lose together; t5 is on the opposing team here
      create_game!([alice, t3, t4], [o1, o2, t5], :team_b_won, ~U[2026-05-05 12:00:00.000000Z])
      # t5 with alice wins → 0 losses / 1 game (as a teammate)
      create_game!([alice, t5], [o1, o2], :team_a_won, ~U[2026-05-06 12:00:00.000000Z])
      create_game!([alice, t2], [o1, o2], :draw, ~U[2026-05-07 12:00:00.000000Z])

      # 6 games × 4 players + 1 game × 6 players = 30 player_results rows.
      await_results(baseline + 30)

      %{alice: alice, t1: t1, t2: t2, t3: t3, t4: t4, t5: t5, o1: o1}
    end

    test "excludes opponents — o1 never shared a team with alice", %{alice: alice, o1: o1} do
      result = Players.least_favorite_team(alice.id, sort: :wins, limit: 10)
      refute Enum.any?(result, &(&1.player_id == o1.id))
    end

    test "excludes the target player themselves", %{alice: alice} do
      result = Players.least_favorite_team(alice.id, sort: :wins, limit: 10)
      refute Enum.any?(result, &(&1.player_id == alice.id))
    end

    test "counts losses over shared games; draws are games but not losses", %{
      alice: alice,
      t1: t1,
      t2: t2
    } do
      result = Players.least_favorite_team(alice.id, sort: :wins, limit: 10)
      assert %PlayerStat{wins: 2, games: 3} = Enum.find(result, &(&1.player_id == t1.id))
      # t2 drew once and lost once: 1 loss over 2 shared games.
      assert %PlayerStat{wins: 1, games: 2} = Enum.find(result, &(&1.player_id == t2.id))
    end

    test "default sort is :points, default limit is 5", %{alice: alice} do
      result = Players.least_favorite_team(alice.id)
      assert length(result) == 5
      assert Enum.sort_by(result, & &1.points, :desc) == result
    end

    test "sorting by :wins ranks t1 first (most shared losses)", %{alice: alice, t1: t1} do
      assert [%PlayerStat{player_id: id, wins: 2} | _] =
               Players.least_favorite_team(alice.id, sort: :wins, limit: 5)

      assert id == t1.id
    end

    test "returns [] for a player with no games" do
      {:ok, ghost} = Players.create_player("Ghost-#{System.unique_integer([:positive])}")
      assert Players.least_favorite_team(ghost.id) == []
    end

    test "games_ratio uses the target's own total games as denominator", %{
      alice: alice,
      t1: t1
    } do
      result = Players.least_favorite_team(alice.id, sort: :wins, limit: 10)
      stat = Enum.find(result, &(&1.player_id == t1.id))
      # Alice played 7 games total; t1 shared the team in 3 → 3/7 * 100 = 42.857
      assert_in_delta stat.games_ratio, 3 / 7 * 100, 0.01
    end
  end

  describe "least_favorite_opponents/2" do
    setup do
      unique = System.unique_integer([:positive])
      {:ok, season} = Seasons.create_season("season-#{unique}")
      {:ok, _} = Seasons.activate_season(season.name)
      {:ok, alice} = Players.create_player("Alice-#{unique}")
      {:ok, b1} = Players.create_player("B1-#{unique}")
      {:ok, opp_a} = Players.create_player("OppA-#{unique}")
      {:ok, opp_b} = Players.create_player("OppB-#{unique}")
      {:ok, opp_c} = Players.create_player("OppC-#{unique}")
      {:ok, opp_d} = Players.create_player("OppD-#{unique}")
      {:ok, opp_e} = Players.create_player("OppE-#{unique}")

      baseline = Repo.aggregate(PlayerResult, :count)

      # opp_a: alice lost g1+g2, drew g3 → 2 losses-against / 3 games-against
      create_game!([alice], [opp_a], :team_b_won, ~U[2026-06-01 12:00:00.000000Z])
      create_game!([alice], [opp_a], :team_b_won, ~U[2026-06-02 12:00:00.000000Z])
      create_game!([alice], [opp_a], :draw, ~U[2026-06-03 12:00:00.000000Z])
      # opp_b: alice lost → 1 loss-against / 1 game
      create_game!([alice], [opp_b], :team_b_won, ~U[2026-06-04 12:00:00.000000Z])
      # opp_c, opp_d: alice (with b1) lost → each 1 loss-against / 1 game
      create_game!([alice, b1], [opp_c, opp_d], :team_b_won, ~U[2026-06-05 12:00:00.000000Z])
      # opp_e: alice won → 0 losses-against / 1 game
      create_game!([alice], [opp_e], :team_a_won, ~U[2026-06-06 12:00:00.000000Z])

      # Row count: 2 + 2 + 2 + 2 + 4 + 2 = 14
      await_results(baseline + 14)

      %{
        alice: alice,
        b1: b1,
        opp_a: opp_a,
        opp_b: opp_b,
        opp_c: opp_c,
        opp_d: opp_d,
        opp_e: opp_e
      }
    end

    test "excludes teammates — b1 never opposed alice", %{alice: alice, b1: b1} do
      result = Players.least_favorite_opponents(alice.id, sort: :wins, limit: 10)
      refute Enum.any?(result, &(&1.player_id == b1.id))
    end

    test "excludes the target themselves", %{alice: alice} do
      result = Players.least_favorite_opponents(alice.id, sort: :wins, limit: 10)
      refute Enum.any?(result, &(&1.player_id == alice.id))
    end

    test "draws count as games-against but NOT as losses-against", %{alice: alice, opp_a: opp_a} do
      result = Players.least_favorite_opponents(alice.id, sort: :wins, limit: 10)
      stat = Enum.find(result, &(&1.player_id == opp_a.id))
      assert %PlayerStat{wins: 2, games: 3} = stat
      assert_in_delta stat.win_ratio, 2 / 3 * 100, 0.01
    end

    test "default sort is :points, default limit is 5", %{alice: alice} do
      result = Players.least_favorite_opponents(alice.id)
      assert length(result) == 5
      assert Enum.sort_by(result, & &1.points, :desc) == result
    end

    test "sorting by :wins ranks opp_a first (2 losses-against)", %{alice: alice, opp_a: opp_a} do
      assert [%PlayerStat{player_id: id, wins: 2} | _] =
               Players.least_favorite_opponents(alice.id, sort: :wins, limit: 5)

      assert id == opp_a.id
    end

    test "sorting by :win_ratio ranks 100%-loss opponents above opp_a (66.7%)", %{
      alice: alice,
      opp_a: opp_a,
      opp_b: opp_b,
      opp_c: opp_c,
      opp_d: opp_d
    } do
      [first, second, third | _] =
        Players.least_favorite_opponents(alice.id, sort: :win_ratio, limit: 5)

      top3 = MapSet.new([first.player_id, second.player_id, third.player_id])
      assert top3 == MapSet.new([opp_b.id, opp_c.id, opp_d.id])
      refute opp_a.id in top3
    end

    test "returns [] for a player with no games" do
      {:ok, ghost} = Players.create_player("Ghost-#{System.unique_integer([:positive])}")
      assert Players.least_favorite_opponents(ghost.id) == []
    end

    test "games_ratio uses the target's own total games as denominator", %{
      alice: alice,
      opp_a: opp_a
    } do
      result = Players.least_favorite_opponents(alice.id, sort: :wins, limit: 10)
      stat = Enum.find(result, &(&1.player_id == opp_a.id))
      # Alice played 6 games total; opp_a was opponent in 3 → 3/6 * 100 = 50
      assert_in_delta stat.games_ratio, 50.0, 0.01
    end
  end

  defp create_game!(team_a, team_b, outcome, played_at) do
    {:ok, command} =
      Games.create_game(%{
        team_a_names: Enum.map(team_a, & &1.name),
        team_b_names: Enum.map(team_b, & &1.name),
        outcome: outcome,
        played_at: played_at
      })

    command
  end

  defp await_results(expected, timeout \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_await_results(expected, deadline)
  end

  defp do_await_results(expected, deadline) do
    if Repo.aggregate(PlayerResult, :count) >= expected do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("PlayerResults projector did not catch up: expected at least #{expected} rows")
      else
        Process.sleep(25)
        do_await_results(expected, deadline)
      end
    end
  end
end
