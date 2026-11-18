defmodule Fskick.Players.Projectors.Player do
  use Commanded.Projections.Ecto,
    application: Fskick.App,
    repo: Fskick.Repo,
    name: "Fskick.Players.Projectors.Player"

  import Ecto.Query, only: [from: 2]

  alias Fskick.Players.Events.PlayerCreated
  alias Fskick.Players.Events.PlayerRenamed

  project(%PlayerCreated{player_id: id, name: name}, metadata, fn multi ->
    Ecto.Multi.insert(multi, :player, %Fskick.Players.Player{
      id: id,
      name: name,
      created_at: metadata.created_at
    })
  end)

  project(%PlayerRenamed{player_id: id, name: name}, _metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :player,
      from(p in Fskick.Players.Player, where: p.id == ^id),
      set: [name: name, updated_at: NaiveDateTime.utc_now(:second)]
    )
  end)
end
