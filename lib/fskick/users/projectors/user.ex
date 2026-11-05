defmodule Fskick.Users.Projectors.User do
  use Commanded.Projections.Ecto,
    application: Fskick.App,
    repo: Fskick.Repo,
    name: "Fskick.Users.Projectors.User"

  import Ecto.Query, only: [from: 2]

  alias Fskick.EventStore.JsonSerializer
  alias Fskick.Users.Events.UserDataDeleted
  alias Fskick.Users.Events.UserRegistered

  project(%UserRegistered{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :user, %Fskick.Users.User{
      id: event.user_id,
      player_id: event.player_id,
      email: projected_email(event),
      hashed_password: event.hashed_password,
      created_at: metadata.created_at
    })
  end)

  project(%UserDataDeleted{user_id: id}, _metadata, fn multi ->
    Ecto.Multi.delete_all(multi, :user, from(u in Fskick.Users.User, where: u.id == ^id))
  end)

  # An erased user's email decrypts to the serializer tombstone, which is the
  # same string for every user. Inserting it verbatim would collide on the
  # `users.email` unique index the moment two erased users replay before their
  # respective `UserDataDeleted` events land, so give each one a unique value.
  # The row is short-lived either way — the deletion follows on replay.
  defp projected_email(%UserRegistered{user_id: id, email: email}) do
    if email == JsonSerializer.tombstone() do
      "redacted-#{id}"
    else
      email
    end
  end
end
