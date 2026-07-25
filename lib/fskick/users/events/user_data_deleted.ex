defmodule Fskick.Users.Events.UserDataDeleted do
  @moduledoc """
  A user's personal data was erased (right-to-erasure). Carries no PII — the
  actual shredding happens by deleting the user's crypto key; this event drives
  the read-model scrub.
  """

  @derive Jason.Encoder
  defstruct [:user_id]
end
