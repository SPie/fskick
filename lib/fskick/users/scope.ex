defmodule Fskick.Users.Scope do
  @moduledoc """
  Request/session scope carrying the authenticated user (if any).

  Phoenix 1.8 threads a `Scope` struct through assigns rather than a bare
  `current_user`, so it can grow to carry more context (roles, etc.) later.
  """

  alias Fskick.Users.Scope
  alias Fskick.Users.User

  defstruct user: nil

  @doc "Build a scope for a user, or `nil` for an anonymous visitor."
  def for_user(%User{} = user), do: %Scope{user: user}
  def for_user(nil), do: nil
end
