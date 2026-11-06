defmodule Fskick.Players.Projectors.PlayerTest do
  use Fskick.DataCase

  alias Fskick.Players.Events.PlayerCreated
  alias Fskick.Players.Events.PlayerRenamed
  alias Fskick.Players.Player
  alias Fskick.Players.Projectors.Player, as: Projector

  test "PlayerRenamed updates the name" do
    id = Ecto.UUID.generate()

    assert :ok = project(%PlayerCreated{player_id: id, name: "Alice"}, 1)
    assert :ok = project(%PlayerRenamed{player_id: id, name: "Alicia"}, 2)

    assert %Player{name: "Alicia"} = Repo.get(Player, id)
  end

  test "a released name can be taken by a later player on replay" do
    alice = Ecto.UUID.generate()
    bob = Ecto.UUID.generate()

    assert :ok = project(%PlayerCreated{player_id: alice, name: "Alice"}, 1)
    assert :ok = project(%PlayerRenamed{player_id: alice, name: "Alicia"}, 2)
    assert :ok = project(%PlayerCreated{player_id: bob, name: "Alice"}, 3)

    assert %Player{name: "Alicia"} = Repo.get(Player, alice)
    assert %Player{name: "Alice"} = Repo.get(Player, bob)
  end

  # Drives the projector directly. The handler name is unique per test run so
  # the version tracking never contends with the running projector's own row.
  defp project(event, event_number) do
    Projector.handle(event, %{
      handler_name: "test-#{inspect(self())}",
      event_number: event_number,
      created_at: DateTime.utc_now()
    })
  end
end
