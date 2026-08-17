defmodule Fskick.CQRS.Projection do
  @moduledoc """
  Helpers for synchronising with Commanded read-model projections.

  After dispatching a command through `Fskick.App`, callers use
  `await/3` to block until the corresponding projector has written
  (or updated) the row in the read model. Pass `:match` to wait for a
  specific row state — e.g. `match: & &1.active` to wait until the row
  exists and a predicate returns true.

  `await_absence/3` is the mirror image: it blocks until the projector
  has *removed* the row, for commands whose projection deletes it.
  """

  alias Fskick.Repo

  @default_wait_ms 5_000
  @poll_interval_ms 25

  @doc """
  Poll the read model for `schema` with the given `id` until the row
  exists and the optional `:match` predicate returns true, or the
  timeout elapses.

  ## Options

  - `:timeout` — milliseconds to wait (default `#{@default_wait_ms}`).
  - `:match` — single-arity predicate run against the loaded struct.
    Defaults to `fn _ -> true end` (any existing row matches).

  Returns `{:ok, struct}` on success, or `{:error, :projection_timeout}`
  if the projection does not catch up in time.
  """
  def await(schema, id, opts \\ []) do
    poll(fn -> Repo.get(schema, id) end, opts, match_check(opts))
  end

  @doc """
  Like `await/3`, but addresses the row with `Repo.get_by/2` clauses
  instead of a primary key — needed for read models with a composite
  primary key, such as `Fskick.Games.PlayerResult` (`player_id`,
  `game_id`) and `Fskick.Games.PlayerStats` (`season_id`, `player_id`).

  Takes the same `:timeout` and `:match` options as `await/3`.
  """
  def await_by(schema, clauses, opts \\ []) do
    poll(fn -> Repo.get_by(schema, clauses) end, opts, match_check(opts))
  end

  defp match_check(opts) do
    match = Keyword.get(opts, :match, fn _ -> true end)

    fn
      nil -> :retry
      struct -> if match.(struct), do: {:halt, {:ok, struct}}, else: :retry
    end
  end

  @doc """
  Poll the read model for `schema` with the given `id` until the row is
  gone, or the timeout elapses.

  ## Options

  - `:timeout` — milliseconds to wait (default `#{@default_wait_ms}`).

  Returns `:ok` once the row no longer exists, or
  `{:error, :projection_timeout}` if it is still there when time runs out.
  """
  def await_absence(schema, id, opts \\ []) do
    poll(fn -> Repo.get(schema, id) end, opts, fn
      nil -> {:halt, :ok}
      _struct -> :retry
    end)
  end

  defp poll(fetch, opts, check) do
    timeout = Keyword.get(opts, :timeout, @default_wait_ms)
    deadline = System.monotonic_time(:millisecond) + timeout
    do_poll(fetch, check, deadline)
  end

  defp do_poll(fetch, check, deadline) do
    case check.(fetch.()) do
      {:halt, result} ->
        result

      :retry ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :projection_timeout}
        else
          Process.sleep(@poll_interval_ms)
          do_poll(fetch, check, deadline)
        end
    end
  end
end
