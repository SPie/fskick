defmodule Fskick.Users.Email do
  @moduledoc """
  The rules for a user's email address, shared by every command that accepts
  one and by login lookups.
  """

  import Ecto.Changeset

  @email_regex ~r/^[^\s]+@[^\s]+\.[^\s]+$/

  @doc "Trim and downcase an email; `nil` passes through."
  def normalize(nil), do: nil

  def normalize(value) when is_binary(value),
    do: value |> String.trim() |> String.downcase()

  @doc "Validate the format and length of the changeset's `:email`."
  def validate(changeset) do
    changeset
    |> validate_format(:email, @email_regex, message: "must be a valid email")
    |> validate_length(:email, max: 160)
  end
end
