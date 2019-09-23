defmodule LiveViewDemo.PlayerList do
  defstruct [
    players: [],
  ]

  def get(player_list, pid) do
    Enum.find(player_list.players, fn(p) -> p.pid == pid end)
  end

  def add(player_list, player) do
    %{player_list | players: [player | player_list.players]}
  end

  def remove(player_list, pid) do
    players = Enum.reject(player_list.players, fn(p) -> p.pid == pid end)

    %{player_list | players: players}
  end

  def reset_turn_scores(player_list) do
    players = player_list.players
      |> Enum.map(fn player -> %{player | turn_score: 0} end)

    %{player_list | players: players}
  end

  def update_game_scores(player_list) do
    players = player_list.players
      |> Enum.map(fn player -> %{player | score: player.score + player.turn_score} end)

    %{player_list | players: players}
  end

  def reset_game_scores(player_list) do
    players = player_list.players
      |> Enum.map(fn player -> %{player | score: 0} end)

    %{player_list | players: players}
  end

  def get_pids(player_list) do
    Enum.map(player_list.players, fn(p) -> p.pid end)
  end
end
