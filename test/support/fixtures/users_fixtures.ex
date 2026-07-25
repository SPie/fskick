defmodule Fskick.UsersFixtures do
  @moduledoc """
  Test helpers for creating users and their linked players.
  """

  alias Fskick.Players
  alias Fskick.Users

  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"
  def unique_player_name, do: "Player #{System.unique_integer([:positive])}"
  def valid_user_password, do: "hello world!"

  @doc "Create a user linked to a freshly created player."
  def user_fixture(attrs \\ %{}) do
    email = Map.get(attrs, :email, unique_user_email())
    password = Map.get(attrs, :password, valid_user_password())
    player_name = Map.get(attrs, :player_name, unique_player_name())

    {:ok, user} = Users.register_user_with_new_player(player_name, email, password)
    user
  end

  @doc "Create a player and return it (for linking a user to an existing player)."
  def player_fixture(name \\ nil) do
    {:ok, player} = Players.create_player(name || unique_player_name())
    player
  end
end
