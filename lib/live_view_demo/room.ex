defmodule LiveViewDemo.Room do
  use GenServer

  alias LiveViewDemoWeb.Endpoint, as: PubSub
  alias LiveViewDemo.RoomList
  alias LiveViewDemo.RoomManager

  def join(room_name, player_name) do
    {:ok, room_pid, _} = get(room_name)
    {:ok, topic} = GenServer.call(room_pid, {:join, self(), player_name})

    PubSub.subscribe(topic)
    {:ok, room_pid}
  end

  def draw(room_pid, active_path) do
    GenServer.call(room_pid, {:draw, active_path})
  end

  def draw_end(room_pid) do
    GenServer.call(room_pid, :draw_end)
  end

  def clear(room_pid) do
    GenServer.call(room_pid, :clear)
  end

  def leave(room_pid) do
    GenServer.cast(room_pid, {:leave, self()})
  end

  def get(room_name) do
    case Registry.lookup(RoomManager, room_name) do
      [{pid, _val}] -> {:ok, pid, room_name}
      [] ->
        IO.puts("No rooms with name #{room_name}, creating it.")
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
    IO.puts("INIT ROOM NAME")
    IO.inspect(room_name)

    :timer.send_interval(1000, self(), :tick)

    {:ok, %{
      room_name: room_name,
      time_left: 10,
      topic: "room:" <> room_name,
      active_path: {"black", 5, "", []},
      paths: [],
      players: []
    }}
  end

  def handle_call({:join, player_pid, player_name}, {player_pid, _}, state) do
    player = %{
      pid: player_pid,
      name: player_name,
      score: 0
    }

    state = Map.put(state, :players, [player | state.players])

    IO.puts("Player #{player.name} joined room #{state.room_name}")

    send(player_pid, {:join_room, state})

    {:reply, {:ok, state.topic}, state}
  end

  def handle_call({:draw, active_path}, {player_pid, _}, state) do
    state = Map.put(state, :active_path, active_path)

    PubSub.broadcast_from(player_pid, state.topic, "draw", %{active_path: active_path})

    {:reply, {:ok, active_path}, state}
  end

  def handle_call(:draw_end, {player_pid, _}, state) do
    state = state
      |> Map.put(:paths, state.paths ++ [state.active_path])
      |> Map.put(:active_path, {"black", 5, "", []})

    PubSub.broadcast(state.topic, "drawend", %{active_path: state.active_path, paths: state.paths})

    {:reply, :ok, state}
  end

  def handle_call(:clear, {player_pid, _}, state) do
    state = state
      |> Map.put(:paths, [])
      |> Map.put(:active_path, {"black", 5, "", []})

    PubSub.broadcast(state.topic, "clear", %{})

    {:reply, :ok, state}
  end

  def handle_cast({:leave, player_pid}, state) do
    %{players: players} = state

    p = Enum.find(players, fn(p) -> p.pid == player_pid end)

    players = case Enum.find(players, fn(p) -> p.pid == player_pid end) do
      nil ->
        players
      player ->
        IO.puts("Player #{player.name} left room #{state.room_name}")
        Enum.reject(players, fn(p) -> p.pid == player_pid end)
    end

    state = Map.put(state, :players, players)

    {:noreply, state}
  end

  def handle_info(:tick, state) do
    time_left = state.time_left - 1

    PubSub.broadcast(state.topic, "countdown", %{time_left: time_left})

    state = Map.put(state, :time_left, time_left)

    state = if time_left === 0 do
      PubSub.broadcast(state.topic, "end_round", %{})

      Map.put(state, :time_left, 10)
    else
      state
    end

    {:noreply, state}
  end
end
