defmodule Fskick.Users.User do
  @moduledoc """
  Read-model schema for users.

  Written by `Fskick.Users.Projectors.User` in response to user events. Used
  for login lookups and uniqueness checks; not used for user-input casting.
  On erasure the projector deletes the row outright — keeping a scrubbed one
  would still record, via `player_id`, that an identified person had an
  account. The erasure guarantee itself comes from destroying the user's
  crypto key (`Fskick.Users.Crypto`), not from anything in this table.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "users" do
    field :player_id, :binary_id
    field :email, :string
    field :hashed_password, :string, redact: true
    field :created_at, :utc_datetime_usec

    timestamps()
  end
end
