defmodule Fskick.Users.Events.UserEmailChanged do
  @moduledoc """
  A user changed their email.

  `email` is PII and is crypto-shredded: the serializer encrypts it under the
  user's key before it reaches the event store.
  """

  @derive Jason.Encoder
  defstruct [:user_id, :email]

  defimpl Fskick.PII do
    def spec(_event), do: %{key_field: :user_id, fields: [:email]}
  end
end
