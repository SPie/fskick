defprotocol Fskick.PII do
  @moduledoc """
  Declares which fields of an event carry personal data and which field holds
  the crypto-shredding key id.

  Only events that embed PII implement this protocol. The event-store
  serializer (`Fskick.EventStore.JsonSerializer`) consults it to transparently
  encrypt those fields on write and decrypt (or tombstone) them on read,
  keyed by the value of `key_field`.
  """

  @fallback_to_any false

  @doc """
  Returns `%{key_field: atom, fields: [atom]}` — the struct field whose value
  is the per-user crypto key id, and the list of PII fields to encrypt.
  """
  @spec spec(t) :: %{key_field: atom, fields: [atom]}
  def spec(event)
end
