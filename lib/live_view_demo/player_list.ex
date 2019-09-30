defmodule LiveViewDemo.PlayerList do
  defstruct [
    players: [],
  ]

  def add(player_list, player) do
    players = player_list.players
    pid = player.pid

    %{player_list | players: List.keystore(players, pid, 0, {pid, player})}
      |> update_ranks
  end

  def update(player_list, player) do
    players = List.keyreplace(player_list.players, player.pid, 0, {player.pid, player})

    %{player_list | players: players}
  end

  def remove(player_list, pid) do
    players = List.keydelete(player_list.players, pid, 0)

    %{player_list | players: players}
      |> update_ranks
  end


  def get(player_list, pid) do
    case List.keyfind(player_list.players, pid, 0) do
      {_pid, player} -> player
      nil -> nil
    end
  end

  def has(player_list, pid) do
    List.keymember?(player_list, pid, 0)
  end

  def get_players_sorted(player_list, key) do
    get_players_sorted(player_list, key, :asc)
  end

  def get_players_sorted(player_list, key, :asc) do
    Enum.sort(player_list.players, fn({_, p1}, {_, p2}) ->
      Map.get(p1, key) <= Map.get(p2, key)
    end)
  end

  def get_players_sorted(player_list, key, :desc) do
    Enum.sort(player_list.players, fn({_, p1}, {_, p2}) ->
      Map.get(p1, key) >= Map.get(p2, key)
    end)
  end

  def reset_turn_scores(player_list) do
    players = player_list.players
      |> Enum.map(fn {pid, player} -> {pid, %{player | turn_score: 0}} end)

    %{player_list | players: players}
  end

  def update_game_scores(player_list) do
    players = player_list.players
      |> Enum.map(fn {pid, player} ->
          {pid, %{player | score: player.score + player.turn_score}} 
        end)

    %{player_list | players: players}
      |> update_ranks
  end

  defp update_ranks(player_list) do
    {players, _acc} = player_list
    |> get_players_sorted(:score, :desc)
    |> Enum.map_reduce({1, 0, 0}, &reduce_rank/2)

    %{player_list | players: players}
  end

  def reset_game_scores(player_list) do
    players = player_list.players
      |> Enum.map(fn {pid, player} -> {pid, %{player | score: 0}} end)

    %{player_list | players: players}
  end

  def get_pids(player_list) do
    Enum.map(player_list.players, fn {pid, _player} -> pid end)
  end

  defp reduce_rank(p, acc) do
    {pid, player} = p
    {current_rank, current_score, rank_count} = acc

    if player.score >= current_score do
      {{pid, %{player | rank: current_rank}}, {current_rank, player.score, rank_count + 1}}
    else
      {
        {pid, %{player | rank: current_rank + rank_count}},
        {current_rank + rank_count, player.score, 1}
      }
    end
  end
end
