defmodule Fskick.Users.Events.UserPasswordReset do
  @moduledoc """
  A user set a new password through a password reset link. Kept apart from
  `Fskick.Users.Events.UserPasswordChanged` so the audit history shows how the
  password changed. `hashed_password` is a one-way hash and is stored as-is.
  """

  @derive Jason.Encoder
  defstruct [:user_id, :hashed_password]
end
