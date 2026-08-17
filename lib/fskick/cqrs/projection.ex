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
    match = Keyword.get(opts, :match, fn _ -> true end)

    poll(schema, id, opts, fn
      nil -> :retry
      struct -> if match.(struct), do: {:halt, {:ok, struct}}, else: :retry
    end)
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
    poll(schema, id, opts, fn
      nil -> {:halt, :ok}
      _struct -> :retry
    end)
  end

  defp poll(schema, id, opts, check) do
    timeout = Keyword.get(opts, :timeout, @default_wait_ms)
    deadline = System.monotonic_time(:millisecond) + timeout
    do_poll(schema, id, check, deadline)
  end

  defp do_poll(schema, id, check, deadline) do
    case check.(Repo.get(schema, id)) do
      {:halt, result} ->
        result

      :retry ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :projection_timeout}
        else
          Process.sleep(@poll_interval_ms)
          do_poll(schema, id, check, deadline)
        end
    end
  end
end
