defmodule Fskick.CQRS.ProjectionTest do
  use Fskick.DataCase, async: true

  import Ecto.Query, only: [from: 2]

  alias Fskick.CQRS.Projection
  alias Fskick.Players.Player

  describe "await/3" do
    test "returns {:ok, struct} once the row exists" do
      id = Ecto.UUID.generate()
      Repo.insert!(%Player{id: id, name: "Alice", created_at: DateTime.utc_now()})

      assert {:ok, %Player{id: ^id, name: "Alice"}} = Projection.await(Player, id)
    end

    test "returns the row when it appears before the timeout" do
      id = Ecto.UUID.generate()

      task =
        Task.async(fn ->
          Process.sleep(50)
          Repo.insert!(%Player{id: id, name: "Bob", created_at: DateTime.utc_now()})
        end)

      assert {:ok, %Player{id: ^id}} = Projection.await(Player, id, timeout: 1_000)

      Task.await(task)
    end

    test "returns {:error, :projection_timeout} when the row never appears" do
      assert {:error, :projection_timeout} =
               Projection.await(Player, Ecto.UUID.generate(), timeout: 50)
    end

    test "with :match returns the row only when the predicate is satisfied" do
      id = Ecto.UUID.generate()
      Repo.insert!(%Player{id: id, name: "Alice", created_at: DateTime.utc_now()})

      task =
        Task.async(fn ->
          Process.sleep(50)
          Repo.update_all(from(p in Player, where: p.id == ^id), set: [name: "Bob"])
        end)

      assert {:ok, %Player{name: "Bob"}} =
               Projection.await(Player, id, timeout: 1_000, match: &(&1.name == "Bob"))

      Task.await(task)
    end

    test "with :match returns {:error, :projection_timeout} when the predicate never holds" do
      id = Ecto.UUID.generate()
      Repo.insert!(%Player{id: id, name: "Alice", created_at: DateTime.utc_now()})

      assert {:error, :projection_timeout} =
               Projection.await(Player, id, timeout: 50, match: &(&1.name == "Bob"))
    end
  end

  describe "await_absence/3" do
    test "returns :ok when the row is already gone" do
      assert :ok = Projection.await_absence(Player, Ecto.UUID.generate())
    end

    test "returns :ok once the row disappears before the timeout" do
      id = Ecto.UUID.generate()
      Repo.insert!(%Player{id: id, name: "Alice", created_at: DateTime.utc_now()})

      task =
        Task.async(fn ->
          Process.sleep(50)
          Repo.delete_all(from(p in Player, where: p.id == ^id))
        end)

      assert :ok = Projection.await_absence(Player, id, timeout: 1_000)

      Task.await(task)
    end

    test "returns {:error, :projection_timeout} while the row is still there" do
      id = Ecto.UUID.generate()
      Repo.insert!(%Player{id: id, name: "Alice", created_at: DateTime.utc_now()})

      assert {:error, :projection_timeout} = Projection.await_absence(Player, id, timeout: 50)
    end
  end
end
