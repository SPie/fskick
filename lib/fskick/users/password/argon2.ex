defmodule Fskick.Users.Password.Argon2 do
  @moduledoc """
  Argon2 (`argon2_elixir`) implementation of `Fskick.Users.Password.Adapter`.

  This is the only module in the app that names the hashing library.

  Note on naming: `defmodule` with a dotted name creates no alias for itself
  (only a `defmodule` nested inside another one does), so the bare `Argon2.`
  calls below resolve to the top-level dependency, not to this module.
  """

  @behaviour Fskick.Users.Password.Adapter

  @impl true
  def hash(password), do: Argon2.hash_pwd_salt(password)

  @impl true
  def valid?(password, hashed_password), do: Argon2.verify_pass(password, hashed_password)

  @impl true
  def no_user_verify, do: Argon2.no_user_verify()
end
