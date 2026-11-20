defmodule Fskick.LegacyMigrationTest do
  use Fskick.DataCase, async: false

  alias Exqlite.Sqlite3
  alias Fskick.Games.PlayerResult
  alias Fskick.LegacyMigration
  alias Fskick.Players
  alias Fskick.Players.Player
  alias Fskick.Seasons.Season

  describe "build_teams/1" do
    test "mixed wins/losses → :team_a_won with winners on team_a" do
      attendances = [
        %{uuid: "p1", win: true},
        %{uuid: "p2", win: true},
        %{uuid: "p3", win: false}
      ]

      assert {:ok, {["p1", "p2"], ["p3"], :team_a_won}} =
               LegacyMigration.build_teams(attendances)
    end

    test "all wins → :draw with every player on team_a, team_b empty" do
      attendances = Enum.map(~w(p1 p2 p3 p4), &%{uuid: &1, win: true})

      assert {:ok, {["p1", "p2", "p3", "p4"], [], :draw}} =
               LegacyMigration.build_teams(attendances)
    end

    test "all losses → :team_b_won with every player on team_a, team_b empty" do
      attendances = Enum.map(~w(p1 p2 p3), &%{uuid: &1, win: false})

      assert {:ok, {["p1", "p2", "p3"], [], :team_b_won}} =
               LegacyMigration.build_teams(attendances)
    end

    test "single winning attendance → one-team :draw with that player on team_a" do
      assert {:ok, {["p1"], [], :draw}} =
               LegacyMigration.build_teams([%{uuid: "p1", win: true}])
    end

    test "single losing attendance → one-team :team_b_won with that player on team_a" do
      assert {:ok, {["p1"], [], :team_b_won}} =
               LegacyMigration.build_teams([%{uuid: "p1", win: false}])
    end

    test "zero attendances → {:error, :no_attendances}" do
      assert {:error, :no_attendances} = LegacyMigration.build_teams([])
    end
  end

  describe "parse_datetime/1" do
    test "parses 'YYYY-MM-DD HH:MM:SS' as UTC" do
      assert LegacyMigration.parse_datetime("2024-06-27 19:19:08") == ~U[2024-06-27 19:19:08Z]
    end

    test "parses with fractional seconds" do
      assert LegacyMigration.parse_datetime("2024-06-27 19:19:08.123456") ==
               ~U[2024-06-27 19:19:08.123456Z]
    end

    test "parses ISO 8601 with explicit Z" do
      assert LegacyMigration.parse_datetime("2024-06-27T19:19:08Z") == ~U[2024-06-27 19:19:08Z]
    end
  end

  describe "migrate_all/1 (smoke test against a tmp SQLite fixture)" do
    setup do
      # The migration reports progress via Mix.shell(); send it to this process
      # instead of stdout so the test run stays quiet.
      Mix.shell(Mix.Shell.Process)
      on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

      unique = System.unique_integer([:positive])
      path = Path.join(System.tmp_dir!(), "fskick_legacy_#{unique}.db")
      on_exit(fn -> File.rm(path) end)

      season_uuid = Ecto.UUID.generate()
      alice_uuid = Ecto.UUID.generate()
      bob_uuid = Ecto.UUID.generate()
      carol_uuid = Ecto.UUID.generate()
      game1_uuid = Ecto.UUID.generate()
      game2_uuid = Ecto.UUID.generate()

      build_fixture!(path, %{
        unique: unique,
        season_uuid: season_uuid,
        alice_uuid: alice_uuid,
        bob_uuid: bob_uuid,
        carol_uuid: carol_uuid,
        game1_uuid: game1_uuid,
        game2_uuid: game2_uuid
      })

      baseline = Repo.aggregate(PlayerResult, :count)

      %{
        path: path,
        season_uuid: season_uuid,
        alice_uuid: alice_uuid,
        bob_uuid: bob_uuid,
        carol_uuid: carol_uuid,
        game1_uuid: game1_uuid,
        game2_uuid: game2_uuid,
        baseline: baseline
      }
    end

    test "imports seasons, players, and games from the legacy DB", ctx do
      assert :ok = LegacyMigration.migrate_all(ctx.path)

      assert %Player{} = Players.get_player(ctx.alice_uuid)
      assert %Player{} = Players.get_player(ctx.bob_uuid)
      assert %Player{} = Players.get_player(ctx.carol_uuid)

      assert %Season{active: true} = Repo.get(Season, ctx.season_uuid)
      assert_received {:mix_shell, :info, ["Seasons: imported 1, skipped 0"]}

      # Game 1 emits 3 player_result rows, Game 2 emits 2 → +5 total.
      await_results(ctx.baseline + 5)
    end

    test "re-running is a no-op", ctx do
      assert :ok = LegacyMigration.migrate_all(ctx.path)
      await_results(ctx.baseline + 5)
      after_first = Repo.aggregate(PlayerResult, :count)

      assert :ok = LegacyMigration.migrate_all(ctx.path)
      after_second = Repo.aggregate(PlayerResult, :count)

      assert after_first == after_second
    end
  end

  defp build_fixture!(path, ids) do
    {:ok, conn} = Sqlite3.open(path)

    :ok =
      Sqlite3.execute(conn, """
      CREATE TABLE seasons (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        uuid TEXT NOT NULL UNIQUE
      );
      """)

    :ok =
      Sqlite3.execute(conn, """
      CREATE TABLE players (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        uuid TEXT NOT NULL UNIQUE
      );
      """)

    :ok =
      Sqlite3.execute(conn, """
      CREATE TABLE games (
        id INTEGER PRIMARY KEY,
        season_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        uuid TEXT NOT NULL UNIQUE,
        played_at TEXT
      );
      """)

    :ok =
      Sqlite3.execute(conn, """
      CREATE TABLE attendances (
        id INTEGER PRIMARY KEY,
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        win INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
      """)

    %{
      unique: unique,
      season_uuid: season_uuid,
      alice_uuid: alice_uuid,
      bob_uuid: bob_uuid,
      carol_uuid: carol_uuid,
      game1_uuid: game1_uuid,
      game2_uuid: game2_uuid
    } = ids

    :ok =
      Sqlite3.execute(conn, """
      INSERT INTO seasons (id, name, active, created_at, uuid) VALUES
        (1, 'Season-legacy-#{unique}', 1, '2026-01-01 00:00:00', '#{season_uuid}');
      """)

    :ok =
      Sqlite3.execute(conn, """
      INSERT INTO players (id, name, created_at, updated_at, uuid) VALUES
        (1, 'Alice-legacy-#{unique}', '2026-01-01 00:00:00', '2026-01-01 00:00:00', '#{alice_uuid}'),
        (2, 'Bob-legacy-#{unique}',   '2026-01-01 00:00:00', '2026-01-01 00:00:00', '#{bob_uuid}'),
        (3, 'Carol-legacy-#{unique}', '2026-01-01 00:00:00', '2026-01-01 00:00:00', '#{carol_uuid}');
      """)

    :ok =
      Sqlite3.execute(conn, """
      INSERT INTO games (id, season_id, created_at, updated_at, played_at, uuid) VALUES
        (1, 1, '2026-02-01 00:00:00', '2026-02-01 00:00:00', '2026-02-01 12:00:00', '#{game1_uuid}'),
        (2, 1, '2026-02-02 00:00:00', '2026-02-02 00:00:00', '2026-02-02 12:00:00', '#{game2_uuid}');
      """)

    # Game 1: Alice + Bob beat Carol (team_a_won).
    # Game 2: Alice + Bob draw against each other (everyone won → :draw).
    :ok =
      Sqlite3.execute(conn, """
      INSERT INTO attendances (id, game_id, player_id, win, created_at, updated_at) VALUES
        (1, 1, 1, 1, '2026-02-01 00:00:00', '2026-02-01 00:00:00'),
        (2, 1, 2, 1, '2026-02-01 00:00:00', '2026-02-01 00:00:00'),
        (3, 1, 3, 0, '2026-02-01 00:00:00', '2026-02-01 00:00:00'),
        (4, 2, 1, 1, '2026-02-02 00:00:00', '2026-02-02 00:00:00'),
        (5, 2, 2, 1, '2026-02-02 00:00:00', '2026-02-02 00:00:00');
      """)

    Sqlite3.close(conn)
  end

  defp await_results(expected, timeout \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_await(expected, deadline)
  end

  defp do_await(expected, deadline) do
    if Repo.aggregate(PlayerResult, :count) >= expected do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("PlayerResults projector did not catch up: expected #{expected} rows")
      else
        Process.sleep(25)
        do_await(expected, deadline)
      end
    end
  end
end
