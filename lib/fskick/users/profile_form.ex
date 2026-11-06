defmodule Fskick.Users.ProfileForm do
  @moduledoc """
  Backs the profile edit form, which spans two aggregates: email and password
  belong to the user, the name to the linked player.

  Decides which commands a submission calls for and collects their errors onto
  one changeset. The validation rules themselves stay on the commands.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Fskick.Players.Commands.RenamePlayer
  alias Fskick.Players.Player
  alias Fskick.Users.Commands.ChangeUserEmail
  alias Fskick.Users.Commands.ChangeUserPassword
  alias Fskick.Users.Email
  alias Fskick.Users.User

  @fields [:email, :player_name, :current_password, :password, :password_confirmation]

  @primary_key false
  embedded_schema do
    field :email, :string
    field :player_name, :string
    field :current_password, :string, redact: true
    field :password, :string, redact: true
    field :password_confirmation, :string, redact: true
  end

  @doc """
  A changeset over the form, with email and player name defaulting to the
  current values. `player` is `nil` for a user without a linked player.
  """
  def changeset(%User{} = user, player, attrs \\ %{}) do
    # Only "" means empty, so a whitespace-only password field counts as filled
    # and is rejected by the command instead of being skipped.
    cast(
      %__MODULE__{email: user.email, player_name: player && player.name},
      attrs,
      @fields,
      empty_values: [""]
    )
  end

  @doc """
  The validated commands for a submission, in the order they should be applied.

  A command is only built for what actually changed: email and player name are
  compared with their current values after normalisation, and the password is
  left alone only when all three password fields are empty.

  Returns `{:ok, commands}` or `{:error, changeset}` with the errors of every
  invalid command.
  """
  def commands(%User{} = user, player, attrs) do
    changeset = changeset(user, player, attrs)

    results =
      Enum.reject(
        [
          rename_player(changeset, player),
          change_email(changeset, user),
          change_password(changeset, user)
        ],
        &(&1 == :unchanged)
      )

    with {:ok, _form} <-
           results |> Enum.reduce(changeset, &merge_errors/2) |> apply_action(:update) do
      {:ok, for({:ok, command} <- results, do: command)}
    end
  end

  defp rename_player(_changeset, nil), do: :unchanged

  defp rename_player(changeset, %Player{id: id, name: current_name}) do
    case get_field(changeset, :player_name) do
      nil -> RenamePlayer.new(%{player_id: id, name: nil})
      name -> rename_player(id, String.trim(name), current_name)
    end
  end

  defp rename_player(_id, name, name), do: :unchanged
  defp rename_player(id, name, _current_name), do: RenamePlayer.new(%{player_id: id, name: name})

  defp change_email(changeset, %User{id: id, email: current_email}) do
    case changeset |> get_field(:email) |> Email.normalize() do
      ^current_email -> :unchanged
      email -> ChangeUserEmail.new(%{user_id: id, email: email})
    end
  end

  defp change_password(changeset, %User{id: id}) do
    passwords =
      Map.take(changeset.changes, [:current_password, :password, :password_confirmation])

    if map_size(passwords) == 0 do
      :unchanged
    else
      passwords |> Map.put(:user_id, id) |> ChangeUserPassword.new()
    end
  end

  defp merge_errors({:ok, _command}, changeset), do: changeset

  defp merge_errors({:error, %Ecto.Changeset{errors: errors}}, changeset) do
    Enum.reduce(errors, changeset, fn {field, {message, opts}}, acc ->
      add_error(acc, form_field(field), message, opts)
    end)
  end

  defp form_field(:name), do: :player_name
  defp form_field(field), do: field
end
