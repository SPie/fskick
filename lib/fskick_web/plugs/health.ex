defmodule FskickWeb.Plugs.Health do
  @moduledoc """
  Health endpoints for Kubernetes probes, mounted in the endpoint ahead of
  sessions and the router so probes stay cheap and stateless.

    * `GET /health/live` — the VM is up. Never touches the database, so a
      database outage does not make Kubernetes restart every pod.
    * `GET /health/ready` — `Fskick.Repo` answers a query. While this fails
      the pod is taken out of the Service and receives no traffic.

  Both paths are excluded from `force_ssl` in `config/prod.exs`: kubelet probes
  hit the pod IP over plain HTTP.
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{method: "GET", path_info: ["health", "live"]} = conn, _opts) do
    conn
    |> send_resp(200, "ok")
    |> halt()
  end

  def call(%Plug.Conn{method: "GET", path_info: ["health", "ready"]} = conn, _opts) do
    {status, body} =
      case Ecto.Adapters.SQL.query(Fskick.Repo, "SELECT 1", []) do
        {:ok, _} -> {200, "ok"}
        {:error, _} -> {503, "database unavailable"}
      end

    conn
    |> send_resp(status, body)
    |> halt()
  end

  def call(conn, _opts), do: conn
end
