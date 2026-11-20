defmodule Fskick.Users.PasswordResetRequest do
  @moduledoc """
  The input of the forgot-password form: the email to send a reset link to.

  Not a command — a request is not event-sourced (see `Fskick.Users` for why) —
  but validated the same way: the email is normalised, required and must be
  well-formed. Whether an account exists is deliberately not checked here, so
  the form's errors never reveal it.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Fskick.Users.Email

  @primary_key false
  embedded_schema do
    field :email, :string
  end

  @doc "A changeset for the forgot-password form, for use with `to_form/2`."
  def changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:email])
    |> update_change(:email, &Email.normalize/1)
    |> validate_required([:email])
    |> Email.validate()
  end

  @doc """
  Build a validated `%PasswordResetRequest{}` from raw attrs.

  Returns `{:ok, request}` or `{:error, changeset}`.
  """
  def new(attrs) do
    attrs
    |> changeset()
    |> apply_action(:insert)
  end
end
