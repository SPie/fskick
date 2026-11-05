defmodule Fskick.Users.Events.UserLoggedIn do
  @moduledoc """
  A user started a session. Audit history only — the aggregate's *state* is
  unchanged by this event, so it does not grow with every login.

  Carries no PII and, deliberately, no session token: the credential lives in
  the `user_sessions` table, which is deletable. Only the `session_id` is
  recorded, so a login can be correlated with its logout.

  `expires_at` is an **ISO-8601 string**, not a `DateTime`. The in-memory event
  store adapter used in tests round-trips structs while the JSON serializer used
  in dev/prod returns a string; an explicit string is unambiguous in both.
  """

  @derive Jason.Encoder
  defstruct [:user_id, :session_id, :expires_at]
end
