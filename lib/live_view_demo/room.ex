defmodule LiveViewDemo.Room do
  use GenServer

  alias LiveViewDemoWeb.Endpoint, as: PubSub
  alias LiveViewDemo.RoomList
  alias LiveViewDemo.RoomManager

  @rounds_per_game 3
  @wordpick_duration 5
  @turn_duration 5
  @score_duration 5

  def join(room_name, player_name) do
    {:ok, room_pid, _} = get(room_name)

    case GenServer.call(room_pid, {:join, self(), player_name}) do
      {:ok, room_state} ->
        PubSub.subscribe(room_state.topic)
        {:ok, room_pid, room_state}
      {:error, err} ->
        {:error, err}
    end
  end

  def start_game(room_pid) do
    GenServer.cast(room_pid, :start_game)
  end

  def draw(room_pid, active_path) do
    GenServer.cast(room_pid, {:draw, active_path})
  end

  def draw_end(room_pid) do
    GenServer.cast(room_pid, :draw_end)
  end

  def clear(room_pid) do
    GenServer.cast(room_pid, :clear)
  end

  def chat_send(room_pid, message) do
    GenServer.cast(room_pid, {:chat_send, self(), message})
  end

  def leave(room_pid) do
    GenServer.cast(room_pid, {:leave, self()})
  end

  def get(room_name) do
    case Registry.lookup(RoomManager, room_name) do
      [{pid, _val}] -> {:ok, pid, room_name}
      [] ->
        IO.puts("No room with name #{room_name}. Creating it now.")
        create(room_name)
    end
  end

  def create() do
    :crypto.strong_rand_bytes(6)
      |> Base.url_encode64()
      |> create
  end

  def create(room_name) do
    case DynamicSupervisor.start_child(RoomList, {LiveViewDemo.Room, room_name}) do
      {:ok, pid} -> {:ok, pid, room_name}
      {:error, {:already_started, pid}} -> {:ok, pid, room_name}
      err -> err
    end
  end

  def exists?(room_name) do
    case Registry.lookup(RoomManager, room_name) do
      [{pid, _val}] -> true
      [] -> false
    end
  end

  def start_link(room_name) do
    GenServer.start_link(__MODULE__, room_name, name: {:via, Registry, {RoomManager, room_name}})
  end

  def init(room_name) do
    {:ok, %{
      mode: :lobby,
      room_name: room_name,
      time_left: 0,
      topic: "room:" <> room_name,
      active_path: {"black", 5, "", []},
      paths: [],
      players: [],
      tref: nil
    }}
  end

  def handle_info(:start_round, state) do
    round = state.current_round + 1

    if round > @rounds_per_game do
      send(self(), :end_game)

      {:noreply, state}
    else
      send(self(), :start_turn)

      state = state
        |> Map.put(:current_round, round)
        |> Map.put(:round_players, Enum.reverse(state.players))

      {:noreply, state}
    end
  end

  def handle_info(:start_turn, state) do
    case state.round_players do
      [player | players] ->
        state = state
          |> Map.put(:mode, :turn)
          |> Map.put(:round_players, players)
          |> start_countdown(@turn_duration)

        {:noreply, state}
      [] ->
        send(self(), :end_round)
        {:noreply, state}
    end
  end

  def handle_info(:show_scores, state) do
    state = state
      |> Map.put(:time_left, @score_duration)
      |> Map.put(:mode, :turn_scores)
      |> start_countdown(@score_duration)
      |> broadcast

    {:noreply, state}
  end

  def handle_info(:end_turn, state) do
    send(self(), :start_turn)

    {:noreply, state}
  end

  def handle_info(:end_round, state) do
    send(self(), :start_round)

    {:noreply, state}
  end

  def handle_info(:end_game, state) do
    state = state
      |> Map.put(:mode, :lobby)
      |> broadcast

    {:noreply, state}
  end

  def handle_info(:tick, state) do
    time_left = state.time_left - 1

    if time_left === 0 do
      cancel_timer(state.tref)

      case state.mode do
        :turn ->
          send(self(), :show_scores)
        :turn_scores ->
          send(self(), :end_turn)
        _ -> :ok
      end

      {:noreply, state}
    else
      state = state
        |> Map.put(:time_left, time_left)
        |> broadcast

      {:noreply, state}
    end
  end

  def handle_call({:join, player_pid, player_name}, {player_pid, _}, state) do
    player = %{
      pid: player_pid,
      name: player_name,
      score: 0
    }

    unless find_player(state.players, player_pid) do
      message = {:join, player.name}

      state = state
        |> Map.put(:players, [player | state.players])
        |> broadcast

      PubSub.broadcast(state.topic, "chat", %{message: message})

      {:reply, {:ok, state}, state}
    else
      {:reply, {:error, "Already joined this room."}, state}
    end
  end

  def handle_cast({:draw, active_path}, state) do
    state = state 
      |> Map.put(:active_path, active_path)
      |> broadcast

    {:noreply, state}
  end

  def handle_cast(:draw_end, state) do
    state = state
      |> Map.put(:paths, state.paths ++ [state.active_path])
      |> Map.put(:active_path, {"black", 5, "", []})
      |> broadcast

    {:noreply, state}
  end

  def handle_cast(:clear, state) do
    state = state
      |> Map.put(:paths, [])
      |> Map.put(:active_path, {"black", 5, "", []})
      |> broadcast

    PubSub.broadcast(state.topic, "clear", %{})

    {:noreply, state}
  end

  def handle_cast({:chat_send, player_pid, message}, state) do
    player = find_player(state.players, player_pid)
    message = {:text, player.name, message}

    PubSub.broadcast(state.topic, "chat", %{message: message})

    {:noreply, state}
  end

  def handle_cast(:start_game, state) do
    if state.mode === :lobby do
      IO.puts("Starting game in room #{state.room_name}")
      send(self(), :start_round)

      state = state
        |> Map.put(:current_round, 0)
        |> broadcast

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:leave, player_pid}, state) do
    %{players: players} = state

    p = Enum.find(players, fn(p) -> p.pid == player_pid end)

    players = case find_player(players, player_pid) do
      nil ->
        players
      player ->
        message = {:leave, player.name}
        PubSub.broadcast(state.topic, "chat", %{message: message})

        remove_player(players, player_pid)
    end

    state = state
      |> Map.put(:players, players)
      |> broadcast

    {:noreply, state}
  end

  defp broadcast(state) do
    PubSub.broadcast(state.topic, "update_room", state)
    state
  end

  defp find_player(players, pid) do
    Enum.find(players, fn(p) -> p.pid == pid end)
  end

  defp remove_player(players, pid) do
    Enum.reject(players, fn(p) -> p.pid == pid end)
  end

  defp start_countdown(state, countdown) do
    {:ok, tref} = :timer.send_interval(1000, self(), :tick)

    cancel_timer(state.tref)

    state
      |> Map.put(:time_left, countdown)
      |> Map.put(:tref, tref)
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(tref), do: :timer.cancel(tref)
end
