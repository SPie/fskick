defmodule Fskick.Users.UserNotifier do
  @moduledoc """
  Emails sent to users. Plain text only.
  """

  import Swoosh.Email

  alias Fskick.Mailer
  alias Fskick.Users.PasswordResetToken
  alias Fskick.Users.User

  @doc "Send the link for resetting a forgotten password."
  def deliver_reset_password_instructions(%User{email: email}, url) when is_binary(url) do
    deliver(email, "Reset your fskick password", """
    Hi,

    someone asked to reset the password for your fskick account. You can set a
    new password by visiting the link below:

    #{url}

    The link is valid for #{PasswordResetToken.lifetime_in_minutes()} minutes and can be used once.

    If you didn't request this, you can ignore this email; your password stays
    unchanged.
    """)
  end

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(sender())
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp sender() do
    :fskick
    |> Application.fetch_env!(Mailer)
    |> Keyword.fetch!(:from)
  end
end
