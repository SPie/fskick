defmodule Fskick.Users.CryptoKey do
  @moduledoc """
  Operational store row holding a user's symmetric encryption key.

  Backs crypto-shredding: deleting the row makes that user's encrypted PII in
  the event store permanently unrecoverable. Written directly by the context
  (`Fskick.Users.Crypto`), never by a projector.

  Lives in the event store database, through `Fskick.KeyRepo` — never query it
  with `Fskick.Repo`.
  """
  use Ecto.Schema

  @primary_key {:user_id, :binary_id, autogenerate: false}
  schema "user_crypto_keys" do
    field :key, :binary

    timestamps()
  end
end
