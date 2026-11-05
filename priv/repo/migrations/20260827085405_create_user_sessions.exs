defmodule Fskick.Repo.Migrations.CreateUserSessions do
  use Ecto.Migration

  def change do
    create table(:user_sessions, primary_key: false) do
      # The session id, also recorded in the UserLoggedIn/UserLoggedOut events
      # so a session can be correlated with its audit history.
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :token_hash, :binary, null: false
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(updated_at: false)
    end

    create unique_index(:user_sessions, [:token_hash])
    create index(:user_sessions, [:user_id])
    create index(:user_sessions, [:expires_at])

    # Superseded by user_sessions. Its `context`/`sent_to` columns were never
    # used (there is no email confirmation or password reset flow), and its
    # implicit "60 days since inserted_at" validity is now an explicit
    # `expires_at`. Existing sessions are invalidated; everyone logs in again.
    drop table(:users_tokens)
  end
end
