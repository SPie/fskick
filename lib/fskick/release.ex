defmodule Fskick.Release do
  @moduledoc """
  Release-time tasks invoked by `bin/migrate` in production. Mix is
  unavailable inside a release, so each task loads the application,
  starts the dependencies it needs, and calls into the runtime APIs.
  """

  @app :fskick

  def migrate() do
    load_app()
    migrate_repos()
    init_event_stores()
    migrate_event_stores()
    migrate_key_repo()
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp migrate_repos() do
    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  # `Fskick.KeyRepo` is not in `:ecto_repos` (see `config/config.exs`), so
  # `migrate_repos/0` skips it. It runs last because it points at the event
  # store's database, which `init_event_stores/0` is what guarantees exists.
  defp migrate_key_repo() do
    {:ok, _, _} =
      Ecto.Migrator.with_repo(Fskick.KeyRepo, &Ecto.Migrator.run(&1, :up, all: true))
  end

  defp init_event_stores() do
    {:ok, _} = Application.ensure_all_started(:postgrex)

    for event_store <- Application.fetch_env!(@app, :event_stores) do
      config = event_store.config()
      EventStore.Tasks.Create.exec(config, quiet: true)
      EventStore.Tasks.Init.exec(config, quiet: true)
    end
  end

  defp migrate_event_stores() do
    {:ok, _} = Application.ensure_all_started(:postgrex)

    for event_store <- Application.fetch_env!(@app, :event_stores) do
      config = event_store.config()
      EventStore.Tasks.Migrate.exec(config, quiet: true)
    end
  end

  defp load_app() do
    Application.ensure_all_started(:ssl)
    Application.load(@app)
  end
end
