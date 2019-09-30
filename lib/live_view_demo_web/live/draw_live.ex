defmodule LiveViewDemoWeb.DrawLive do
  use Phoenix.LiveView

  alias LiveViewDemo.Room
  alias LiveViewDemo.PlayerList

  @point_distance 5

  def render(assigns) do
    Phoenix.View.render(LiveViewDemoWeb.DrawView, "index.html", assigns)
  end

  def mount(_session, socket) do
    host = Application.fetch_env!(:live_view_demo, LiveViewDemoWeb.Endpoint)
      |> Keyword.get(:url)
      |> Keyword.get(:host)

    socket = socket
      |> assign(%{
          mode: :init,
          room: nil,
          room_pid: nil,
          room_name: nil,
          messages: [],
          size: 5,
          my_turn: false,
          current_player: nil,
          color: "black",
          host: host
        })

    {:ok, socket}
  end

  def handle_params(%{"room" => room_name}, _url, socket) do
    if connected?(socket) do
      socket = assign(socket,
        room_name: room_name
      )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_params(%{}, _url, socket) do
    room_slug = Base.url_encode64(:crypto.strong_rand_bytes(6))
    {:noreply, live_redirect(socket, to: "/draw/" <> room_slug, replace: true)}
  end

  def handle_info(%{event: "chat", payload: payload}, socket) do
    socket = assign(socket,
      messages: socket.assigns.messages ++ [payload.message]
    )

    {:noreply, socket}
  end

  def handle_info(%{event: "update_room", payload: room_state}, socket) do
    socket = assign(socket,
      room: room_state,
      current_player: PlayerList.get(room_state.players, room_state.current_player_pid),
      my_turn: is_self(room_state.current_player_pid)
    )

    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  def handle_event("set_user", user, socket) do
    name = user["username"]
    room_name = socket.assigns.room_name

    case Room.join(room_name, name) do
      {:ok, room_pid, room} ->
        message = {:join, name}

        socket = assign(socket,
          mode: :joined,
          username: name,
          room_pid: room_pid,
          messages: socket.assigns.messages ++ [message],
          room: room
        )

        {:noreply, socket}
      {:error, _err} ->
        {:noreply, socket}
    end
  end

  def handle_event("start_game", _data, socket) do
    %{ room_pid: room_pid } = socket.assigns

    Room.start_game(room_pid)

    {:noreply, socket}
  end

  def handle_event("drawstart", coords, socket) do
    %{ size: size, color: color, room_pid: room_pid, size: size } = socket.assigns
    x = coords["x"] + (size / 2)
    y = coords["y"] + (size / 2)

    active_path = {color, size, "", []}
      |> add_point([{x, y}])
      |> draw_path()

    Room.draw(room_pid, active_path)

    {:noreply, assign(socket, :active_path, active_path)}
  end

  def handle_event("draw", coords, socket) do
    %{ room: room, room_pid: room_pid, size: size } = socket.assigns
    x = coords["x"] + (size / 2)
    y = coords["y"] + (size / 2)

    active_path = room.active_path
      |> add_point([{x, y}])
      |> draw_path()

    Room.draw(room_pid, active_path)

    {:noreply, assign(socket, :active_path, active_path)}
  end

  def handle_event("drawend", _coords, socket) do
    %{ room_pid: room_pid } = socket.assigns

    Room.draw_end(room_pid)

    {:noreply, socket}
  end

  def handle_event("chat_send", %{"message" => message}, socket) do
    %{ room_pid: room_pid } = socket.assigns

    Room.chat_send(room_pid, message)

    {:noreply, socket}
  end

  def handle_event("pick_word", %{"word" => word}, socket) do
    %{ room_pid: room_pid } = socket.assigns

    Room.pick_word(room_pid, word)

    {:noreply, socket}
  end

  def handle_event("color", %{"color" => color}, socket) do
    {:noreply, assign(socket, :color, color)}
  end

  def handle_event("size", %{"size" => size}, socket) do
    {:noreply, assign(socket, :size, String.to_integer(size))}
  end

  def handle_event("clear", _, socket) do
    Room.clear(socket.assigns.room_pid)

    {:noreply, socket}
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  def terminate(reason, socket) do
    %{room_pid: room_pid} = socket.assigns

    Room.leave(room_pid)
    {:stop, reason}
  end

  defp draw_path({col, size, _path, points}) do
    {col, size, draw_points(points, []), points}
  end

  defp draw_points([], path), do: path
  defp draw_points([{x, y} | []], path) do
    ["M ", Kernel.inspect(x), ",", Kernel.inspect(y), " " | path]
  end
  defp draw_points([{x, y} | points], path) do
    draw_points(points, ["L ", Kernel.inspect(x), ",", Kernel.inspect(y), " " | path])
  end

  # When distance is too small, update last point instead of adding new one
  defp add_point({col, size, path, [p1, p2 | points]}, [{x, y}]) do
    dist = get_distance(p1, p2)

    if dist < @point_distance do
      {col, size, path, [{x, y}, p2 | points]}
    else
      {col, size, path, [{x, y}, p1, p2 | points]}
    end
  end

  defp add_point({col, size, path, []}, [{x, y}]) do
    # Add point once for the M and L instructions respectively
    {col, size, path, [{x, y}, {x, y}]}
  end

  defp get_distance({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
  end

  defp is_self(pid) when pid == self(), do: true
  defp is_self(_), do: false
end
