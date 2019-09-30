defmodule LiveViewDemo.Room do
  use GenServer

  alias LiveViewDemoWeb.Endpoint, as: PubSub
  alias LiveViewDemo.RoomList
  alias LiveViewDemo.RoomManager
  alias LiveViewDemo.Player
  alias LiveViewDemo.PlayerList

  @rounds_per_game 3
  @wordpick_duration 5
  @turn_duration 5
  @score_duration 5

  defstruct [
    mode: :lobby,
    room_name: "Default",
    topic: "room:default",
    time_left: 0,
    active_path: {"black", 5, "", []},
    paths: [],
    players: %PlayerList{},
    current_round: 0,
    num_rounds: @rounds_per_game,
    current_player_pid: nil,
    round_players: [],
    guessword: nil,
    word_options: [],
    word: "",
    obfuscated_word: "",
    tref: nil
  ]

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

  def pick_word(room_pid, word_index) do
    GenServer.cast(room_pid, {:pick_word, self(), word_index})
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
    {:ok, %__MODULE__{
      mode: :lobby,
      room_name: room_name,
      topic: "room:" <> room_name,
    }}
  end

  def handle_info(:start_round, state) do
    round = state.current_round + 1

    if round > state.num_rounds do
      send(self(), :game_scores)

      {:noreply, state}
    else
      send(self(), :start_turn)

      state = state
        |> Map.merge(%{
            current_round: round,
            round_players: state.players
              |> PlayerList.get_pids
              |> Enum.reverse
          })

      {:noreply, state}
    end
  end

  def handle_info(:start_turn, state) do
    players = PlayerList.reset_turn_scores(state.players)

    case state.round_players do
      [current | remaining] ->
        state = state
          |> Map.merge(%{
              players: players,
              current_player_pid: current,
              round_players: remaining
            })

        send(self(), :turn_pick)
        {:noreply, state}
      [] ->
        send(self(), :end_round)
        {:noreply, state}
    end
  end

  def handle_info(:turn_pick, state) do
    state = state
      |> Map.merge(%{
          mode: :turn_pick,
          word: nil,
          word_options: ["Elixir", "Phoenix", "BEAM"]
        })
      |> start_countdown(@wordpick_duration)
      |> broadcast

    {:noreply, state}
  end

  def handle_info(:turn_guess, state) do
    state = unless state.word do
      set_word(state, Enum.at(state.word_options, 0))
    else
      state
    end

    state = state
      |> Map.put(:mode, :turn_guess)
      |> start_countdown(@turn_duration)
      |> broadcast

    {:noreply, state}
  end

  def handle_info(:turn_scores, state) do
    players = PlayerList.update_game_scores(state.players)

    state = state
      |> Map.merge(%{
          mode: :turn_scores,
          players: players
        })
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

  def handle_info(:game_scores, state) do
    players = PlayerList.update_game_scores(state.players)

    state = state
      |> Map.merge(%{
          mode: :game_scores,
          players: players
        })
      |> start_countdown(@score_duration)
      |> broadcast

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

    if time_left < 0 do
      cancel_timer(state.tref)

      case state.mode do
        :turn_pick ->
          send(self(), :turn_guess)
        :turn_guess ->
          send(self(), :turn_scores)
        :turn_scores ->
          send(self(), :end_turn)
        :game_scores ->
          send(self(), :end_game)
        _ ->
          IO.puts("Undefined state transition from #{state.mode}")
          :error
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
    player = %Player{
      pid: player_pid,
      name: player_name,
      turn_score: 0,
      score: 0
    }

    unless PlayerList.get(state.players, player_pid) do
      message = {:join, player.name}

      state = state
        |> Map.put(:players, PlayerList.add(state.players, player))
        |> broadcast

      PubSub.broadcast(state.topic, "chat", %{message: message})

      {:reply, {:ok, state}, state}
    else
      {:reply, {:error, "Already joined this room."}, state}
    end
  end

  def handle_cast({:pick_word, player_pid, word_index}, state) do
    word = Enum.at(state.word_options, String.to_integer(word_index))

    state = state 
      |> set_word(word)
      |> broadcast

    cancel_timer(state.tref)
    send(self(), :turn_guess)

    {:noreply, state}
  end

  def handle_cast({:draw, active_path}, state) do
    state = state 
      |> Map.put(:active_path, active_path)
      |> broadcast

    {:noreply, state}
  end

  def handle_cast(:draw_end, state) do
    state = state
      |> Map.merge(%{
          paths: state.paths ++ [state.active_path],
          active_path: {"black", 5, "", []}
        })
      |> broadcast

    {:noreply, state}
  end

  def handle_cast(:clear, state) do
    state = state
      |> Map.merge(%{
          paths: [],
          active_path: {"black", 5, "", []}
        })
      |> broadcast

    PubSub.broadcast(state.topic, "clear", %{})

    {:noreply, state}
  end

  def handle_cast({:chat_send, player_pid, text}, state) do
    player = PlayerList.get(state.players, player_pid)

    state = case attempt_guess(state, player, text) do
      :match ->
        message = {:guess, player.name}
        score = 100 + state.time_left * 10
        PubSub.broadcast(state.topic, "chat", %{message: message})

        players = state.players
          |> PlayerList.update(%{player | turn_score: score})

        state
          |> Map.put(:players, players)
          |> broadcast
      :no_match ->
        message = {:text, player.name, text}
        PubSub.broadcast(state.topic, "chat", %{message: message})

        state
    end

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

    players = case PlayerList.get(players, player_pid) do
      nil ->
        players
      player ->
        message = {:leave, player.name}
        PubSub.broadcast(state.topic, "chat", %{message: message})

        PlayerList.remove(players, player_pid)
    end

    state = state
      |> Map.put(:players, players)
      |> broadcast

    {:noreply, state}
  end

  defp attempt_guess(state, player, guess) do
    with(
      :turn_guess <- state.mode,
      true <- can_guess(state, player),
      true <- check_guess(state.word, guess)
    ) do
      :match
    else
      _ -> :no_match
    end
  end

  defp can_guess(state, player) do
    player.pid != state.current_player_pid && player.turn_score == 0
  end

  defp check_guess(word, guess) do
    String.downcase(word) == String.downcase(guess)
  end

  defp broadcast(state) do
    PubSub.broadcast(state.topic, "update_room", state)
    state
  end

  defp start_countdown(state, countdown) do
    {:ok, tref} = :timer.send_interval(1000, self(), :tick)

    cancel_timer(state.tref)

    state
      |> Map.merge(%{
          time_left: countdown,
          tref: tref
        })
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(tref), do: :timer.cancel(tref)

  defp set_word(state, word) do
    Map.merge(state, %{
      word: word,
      obfuscated_word: obfuscate(word)
    })
  end

  defp obfuscate(word) do
    Regex.replace(~r{[^-_\s]}, word, "_")
  end
end
