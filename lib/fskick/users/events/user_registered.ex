defmodule Fskick.Users.Events.UserRegistered do
  @moduledoc """
  A user account was registered and linked to a player.

  `email` is PII and is crypto-shredded: the serializer encrypts it under the
  user's key before it reaches the event store. `hashed_password` is a one-way
  Argon2 hash (not reversible, not identifying) and is stored as-is.
  """

  @derive Jason.Encoder
  defstruct [:user_id, :player_id, :email, :hashed_password]

  defimpl Fskick.PII do
    def spec(_event), do: %{key_field: :user_id, fields: [:email]}
  end
end
