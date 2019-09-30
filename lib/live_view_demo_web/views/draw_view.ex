defmodule LiveViewDemoWeb.DrawView do
  use LiveViewDemoWeb, :view

  alias LiveViewDemo.PlayerList

  defp sort_by_turn_score(players) do
    PlayerList.get_players_sorted(players, :turn_score, :desc)
  end

  defp sort_by_game_score(players) do
    PlayerList.get_players_sorted(players, :score, :desc)
  end
end
