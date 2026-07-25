defmodule Fskick.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"

    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :player_id, :uuid, null: false
      add :email, :citext, null: false
      add :hashed_password, :string
      add :created_at, :utc_datetime_usec, null: false

      timestamps()
    end

    create unique_index(:users, [:email])
    create index(:users, [:player_id])
  end
end
