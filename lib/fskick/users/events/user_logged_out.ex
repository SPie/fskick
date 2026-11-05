defmodule Fskick.Users.Events.UserLoggedOut do
  @moduledoc """
  A user ended a session by logging out. Audit history only — the aggregate's
  state is unchanged. Carries no PII and no session token.

  Note that sessions which lapse by reaching their expiry produce no event:
  expiry is a deterministic consequence of the `expires_at` already recorded in
  `Fskick.Users.Events.UserLoggedIn`, not a new fact.
  """

  @derive Jason.Encoder
  defstruct [:user_id, :session_id]
end
