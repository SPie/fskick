defmodule Fskick.Users.Commands.LogInUser do
  @moduledoc """
  Command recording that a user started a session.

  Structural validation lives here: presence of the ids and the expiry.
  The state-dependent invariant (the user must exist) lives in the aggregate.

  This command carries no credential — the session token is *not* part of the
  event-sourced history. See `Fskick.Users.Session`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :user_id, :binary_id
    field :session_id, :binary_id
    # ISO-8601 string, not a DateTime — see Fskick.Users.Events.UserLoggedIn.
    field :expires_at, :string
  end

  @doc """
  Build a validated `%LogInUser{}` from raw attrs.

  Returns `{:ok, command}` or `{:error, changeset}`.
  """
  def new(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :session_id, :expires_at])
    |> validate_required([:user_id, :session_id, :expires_at])
    |> apply_action(:insert)
  end
end
