defmodule Fskick.Users.Events.UserPasswordChanged do
  @moduledoc """
  A user changed their password. `hashed_password` is a one-way password hash
  (not reversible, not identifying) and is stored as-is, like in
  `Fskick.Users.Events.UserRegistered`.
  """

  @derive Jason.Encoder
  defstruct [:user_id, :hashed_password]
end
