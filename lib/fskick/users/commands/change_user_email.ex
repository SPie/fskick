defmodule Fskick.Users.Commands.ChangeUserEmail do
  @moduledoc """
  Command to change a user's email.

  Structural validation lives here: presence, email format/normalisation and
  availability (against the read model, ignoring the user's own row). The
  state-dependent invariant (the user must exist) lives in the aggregate.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias Fskick.Repo
  alias Fskick.Users.Email
  alias Fskick.Users.User

  @primary_key false
  embedded_schema do
    field :user_id, :binary_id
    field :email, :string
  end

  @doc """
  Build a validated `%ChangeUserEmail{}` from raw attrs.

  Returns `{:ok, command}` or `{:error, changeset}`.
  """
  def new(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :email])
    |> update_change(:email, &Email.normalize/1)
    |> validate_required([:user_id, :email])
    |> Email.validate()
    |> validate_email_available()
    |> apply_action(:insert)
  end

  defp validate_email_available(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_email_available(changeset) do
    user_id = get_change(changeset, :user_id)
    email = get_change(changeset, :email)

    if Repo.exists?(from u in User, where: u.email == ^email and u.id != ^user_id) do
      add_error(changeset, :email, "has already been taken")
    else
      changeset
    end
  end
end
