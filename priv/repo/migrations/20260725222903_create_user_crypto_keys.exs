defmodule Fskick.Repo.Migrations.CreateUserCryptoKeys do
  use Ecto.Migration

  # Per-user symmetric keys backing crypto-shredding. Written directly by the
  # Users context (not a projector) since keys cannot be event-sourced without
  # defeating the shredding guarantee. No FK to `users`: the key is created
  # before the aggregate is dispatched, so the projection may not exist yet.
  def change do
    create table(:user_crypto_keys, primary_key: false) do
      add :user_id, :uuid, primary_key: true
      add :key, :binary, null: false

      timestamps()
    end
  end
end
