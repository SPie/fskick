defmodule Fskick.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FskickWeb.Telemetry,
      Fskick.Repo,
      # Before Fskick.App: its subscriptions start deserializing events (and so
      # reading crypto keys) as soon as they boot.
      Fskick.KeyRepo,
      {DNSCluster, query: Application.get_env(:fskick, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Fskick.PubSub},
      Fskick.App,
      Fskick.Players.Projectors.Player,
      Fskick.Seasons.Projectors.Season,
      Fskick.Seasons.ProcessManagers.SoleActiveSeason,
      Fskick.Games.Projectors.Game,
      Fskick.Games.Projectors.PlayerStats,
      Fskick.Games.Projectors.PlayerResults,
      Fskick.Users.Projectors.User,
      FskickWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fskick.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FskickWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
