import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :fskick, Fskick.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  database: "fskick_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# The test event store is in-memory (see below), so there is no event store
# database for the keys to share. They get their own database here instead.
config :fskick, Fskick.KeyRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  database: "fskick_keys_test#{System.get_env("MIX_TEST_PARTITION")}",
  migration_source: "keys_schema_migrations",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fskick, FskickWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "HO7gRZcxJDnGuQSdnXHSnjEahjZqyX3YEMS1PbQzXCodtbbzAHRoruBi8HuFDA+U",
  server: false

# In test we don't send emails
config :fskick, Fskick.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Use in-memory event store for speed; swap to Fskick.EventStore for full integration tests
config :fskick, Fskick.App,
  event_store: [
    adapter: Commanded.EventStore.Adapters.InMemory
  ]

# Hash passwords with a trivial fake in tests; Fskick.Users.Password.Argon2Test
# still exercises the real hasher, kept cheap by the low cost params below.
config :fskick, Fskick.Users.Password, adapter: Fskick.Users.Password.Plain
config :argon2_elixir, t_cost: 1, m_cost: 8

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
