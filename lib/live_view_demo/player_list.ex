defmodule LiveViewDemo.PlayerList do
  defstruct [
    players: [],
  ]

  def add(player_list, player) do
    players = player_list.players
    pid = player.pid

    %{player_list | players: List.keystore(players, pid, 0, {pid, player})}
  end

  def update(player_list, player) do
    players = List.keyreplace(player_list.players, player.pid, 0, {player.pid, player})

    %{player_list | players: players}
  end

  def remove(player_list, pid) do
    players = List.keydelete(player_list.players, pid, 0)

    %{player_list | players: players}
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
  end

  def reset_game_scores(player_list) do
    players = player_list.players
      |> Enum.map(fn {pid, player} -> {pid, %{player | score: 0}} end)

    %{player_list | players: players}
  end

  def get_pids(player_list) do
    Enum.map(player_list.players, fn {pid, _player} -> pid end)
  end
end
