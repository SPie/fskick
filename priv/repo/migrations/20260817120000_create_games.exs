defmodule Fskick.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change() do
    create table(:games, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :season_id, :uuid, null: false
      add :played_at, :utc_datetime_usec, null: false
      add :outcome, :string, null: false
      add :created_at, :utc_datetime_usec, null: false

      timestamps()
    end

    create index(:games, [:season_id, :played_at])
  end
end
