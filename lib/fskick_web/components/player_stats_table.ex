defmodule FskickWeb.Components.PlayerStatsTable do
  @moduledoc """
  Shared player rankings table. Rendered by both `FskickWeb.HomeLive` (per
  season) and `FskickWeb.PlayersLive` (all-time). Sortable headers emit
  `phx-click="sort"` events handled by the enclosing LiveView.
  """
  use Phoenix.Component

  attr :stats, :list, required: true
  attr :games_count, :integer, required: true
  attr :sort, :atom, required: true
  attr :sort_event, :string, default: "sort"
  attr :count_label, :string, default: "Wins"
  attr :ratio_label, :string, default: "Win Ratio"

  attr :highlight_player_id, :string,
    default: nil,
    doc: "player_id whose row should be highlighted (the logged-in user's player)"

  def player_stats_table(assigns) do
    ~H"""
    <table class="mx-auto text-xs md:text-base table-fixed">
      <thead>
        <tr>
          <th class="border-b border-gray-500 text-left px-1 md:px-6 py-4">Pos ({length(@stats)})</th>
          <th class="border-b border-gray-500 text-left px-1 md:px-6 py-4">Player</th>
          <.sort_header sort={@sort} sort_event={@sort_event} key={:points} label="Points" />
          <.sort_header sort={@sort} sort_event={@sort_event} key={:wins} label={@count_label} />
          <.sort_header
            sort={@sort}
            sort_event={@sort_event}
            key={:games}
            label={"Games (#{@games_count})"}
          />
          <.sort_header
            sort={@sort}
            sort_event={@sort_event}
            key={:win_ratio}
            label={@ratio_label}
          />
        </tr>
      </thead>
      <tbody>
        <tr
          :for={stat <- @stats}
          class={stat.player_id == @highlight_player_id && "bg-gray-700 font-bold"}
        >
          <td class="border-b border-gray-500 text-left px-1 md:px-6 py-3">{stat.position}</td>
          <td class="border-b border-gray-500 text-left px-1 md:px-6 py-3 underline">
            <.link navigate={"/players/" <> stat.player_id}>{stat.name}</.link>
          </td>
          <td class="border-b border-gray-500 text-left px-1 md:px-6 py-3">
            {format_float(stat.points)}
          </td>
          <td class="border-b border-gray-500 text-left px-1 md:px-6 py-3">{stat.wins}</td>
          <td class="border-b border-gray-500 text-left px-1 md:px-6 py-3">
            {stat.games} ({format_float(stat.games_ratio)} %)
          </td>
          <td class="border-b border-gray-500 text-left px-1 md:px-6 py-3">
            {format_float(stat.win_ratio)} %
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  attr :sort, :atom, required: true
  attr :sort_event, :string, required: true
  attr :key, :atom, required: true
  attr :label, :string, required: true

  defp sort_header(assigns) do
    ~H"""
    <th
      class={[
        "border-b border-gray-500 text-left px-1 md:px-6 py-4 cursor-pointer",
        @sort == @key && "underline"
      ]}
      phx-click={@sort_event}
      phx-value-sort={Atom.to_string(@key)}
    >
      {@label}
    </th>
    """
  end

  @doc """
  The player_id to highlight for the given auth scope — the logged-in user's
  linked player, or `nil` for anonymous visitors.
  """
  def highlight_id(nil), do: nil
  def highlight_id(%{user: nil}), do: nil
  def highlight_id(%{user: %{player_id: player_id}}), do: player_id

  defp format_float(value) when is_float(value) do
    :erlang.float_to_binary(value, decimals: 2)
  end

  defp format_float(value) when is_integer(value) do
    :erlang.float_to_binary(value * 1.0, decimals: 2)
  end
end
