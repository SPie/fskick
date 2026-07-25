defmodule Fskick.Users.User do
  @moduledoc """
  Read-model schema for users.

  Written by `Fskick.Users.Projectors.User` in response to user events. Used
  for login lookups and uniqueness checks; not used for user-input casting.
  On erasure the projector scrubs `email` to a tombstone and nils
  `hashed_password`.
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
