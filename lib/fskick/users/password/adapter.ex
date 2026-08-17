defmodule Fskick.Users.Password.Adapter do
  @moduledoc """
  Contract for a password hashing implementation.

  Implementations are selected via config; see `Fskick.Users.Password`, the
  facade the rest of the app talks to.

  Two obligations an adapter must honour:

  - `c:hash/1` returns a one-way, salted, self-describing hash — hashing the
    same password twice must produce different output, and `c:valid?/2` must be
    able to verify a hash without any other stored state.
  - `c:no_user_verify/0` burns time comparable to `c:valid?/2` so that response
    timing does not reveal whether an account exists.
  """

  @doc "Hash a password for storage."
  @callback hash(password :: String.t()) :: String.t()

  @doc "Verify a password against a stored hash."
  @callback valid?(password :: String.t(), hashed_password :: String.t()) :: boolean()

  @doc """
  Dummy verification for when there is no hash to check against, to equalise
  response time. Always returns `false`.
  """
  @callback no_user_verify() :: false
end
