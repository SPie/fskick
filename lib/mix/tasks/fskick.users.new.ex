defmodule Mix.Tasks.Fskick.Users.New do
  @moduledoc """
  Creates a new user account, linked to a player.

  Link to an existing player by name or id:

      mix fskick.users.new alice@example.com "s3cret!!" --player-name "Alice"
      mix fskick.users.new alice@example.com "s3cret!!" --player-id <uuid>

  Or create a brand-new player at the same time:

      mix fskick.users.new alice@example.com "s3cret!!" --new-player "Alice"

  Fails if the email already exists, the player cannot be found, or the input
  is invalid.
  """

  use Mix.Task

  alias Fskick.Players
  alias Fskick.Users

  @shortdoc ~s|Creates a user: mix fskick.users.new <email> <password> --player-name "Alice"|

  @switches [player_id: :string, player_name: :string, new_player: :string]

  @impl Mix.Task
  def run(argv) do
    {opts, args, _invalid} = OptionParser.parse(argv, strict: @switches)

    case args do
      [email, password | _] ->
        Mix.Task.run("app.start")
        register(email, password, opts)

      _ ->
        Mix.raise(usage())
    end
  end

  defp register(email, password, opts) do
    result =
      cond do
        name = opts[:new_player] ->
          Users.register_user_with_new_player(name, email, password)

        id = opts[:player_id] ->
          Users.register_user_for_player(id, email, password)

        name = opts[:player_name] ->
          case Players.get_player_by_name(name) do
            nil -> {:error, {:player_not_found, name}}
            player -> Users.register_user_for_player(player.id, email, password)
          end

        true ->
          Mix.raise(usage())
      end

    handle(result, email)
  end

  defp handle({:ok, user}, _email), do: Mix.shell().info("User #{user.email} created")

  defp handle({:error, {:player_not_found, name}}, _email),
    do: Mix.raise("No player found with name #{inspect(name)}")

  defp handle({:error, :projection_timeout}, _email),
    do: Mix.raise("User was created but read model did not catch up in time")

  defp handle({:error, %Ecto.Changeset{} = changeset}, email) do
    if email_taken?(changeset) do
      Mix.raise("User with email #{inspect(email)} already exists")
    else
      Mix.raise("Invalid input: #{format_errors(changeset)}")
    end
  end

  defp handle({:error, reason}, _email),
    do: Mix.raise("Failed to create user: #{inspect(reason)}")

  defp email_taken?(changeset) do
    changeset.errors
    |> Keyword.get_values(:email)
    |> Enum.any?(fn {msg, _opts} -> msg == "has already been taken" end)
  end

  defp format_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
    |> inspect()
  end

  defp usage do
    "Usage: mix fskick.users.new <email> <password> (--player-name NAME | --player-id UUID | --new-player NAME)"
  end
end
