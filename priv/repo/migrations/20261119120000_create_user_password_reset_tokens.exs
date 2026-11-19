defmodule Fskick.Repo.Migrations.CreateUserPasswordResetTokens do
  use Ecto.Migration

  def change do
    create table(:user_password_reset_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :token_hash, :binary, null: false
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create unique_index(:user_password_reset_tokens, [:token_hash])
    create index(:user_password_reset_tokens, [:user_id])
  end
end
