defmodule Fskick.KeyRepo do
  @moduledoc """
  Repo for the per-user crypto keys backing PII shredding
  (`Fskick.Users.Crypto`).

  The keys are the one piece of state that cannot be rebuilt from events —
  losing them shreds every user's PII irreversibly — so they must not live in
  the read-model database, which is designed to be dropped and replayed. This
  repo points at the **event store** database instead: if that database is ever
  destroyed, the encrypted `UserRegistered` payloads go with it, so a key never
  outlives its ciphertext or vice versa.

  Two deliberate configuration details:

  - This repo is **not** listed in `config :fskick, :ecto_repos`. `mix ecto.drop`
    (and therefore `mix ecto.reset`) operates on every repo in that list, which
    would destroy the event store. Keeping it out means the routine read-model
    reset cannot reach it. The cost is that `mix ecto.create`/`ecto.migrate`
    must target it explicitly with `-r Fskick.KeyRepo`; see the `mix.exs`
    aliases and `Fskick.Release.migrate/0`.
  - `migration_source: "keys_schema_migrations"` — the event store database
    already has a `schema_migrations` table owned by EventStore's own migrator.
  """

  use Ecto.Repo,
    otp_app: :fskick,
    adapter: Ecto.Adapters.Postgres
end
