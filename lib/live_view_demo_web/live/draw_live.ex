defmodule LiveViewDemoWeb.DrawLive do
  use Phoenix.LiveView
  import Calendar.Strftime

  alias LiveViewDemoWeb.Endpoint, as: PubSub
  alias LiveViewDemo.Room

  @point_distance 16

  def render(assigns) do
    ~L"""
    <div class="game">
      <div class="status"><%= @time_left %></div>

      <svg class="drawing" xmlns="http://www.w3.org/2000/svg"
        phx-mousedown="drawstart"
        phx-mouseup="drawend"
        phx-mousemove="draw"
        width="600"
        height="400"
        viewBox="0 0 600 400"
      >
        <g>
          <%= for {col, size, path, _} <- @paths do %>
            <path fill="none"
              stroke="<%= col %>"
              stroke-width="<%= size %>"
              d="<%= path %>"
            /></path>
          <% end %>

          <%= with {col, size, path, _} <- @active_path do %>
            <path class="active_path" fill="none"
              stroke="<%= col %>"
              stroke-width="<%= size %>"
              d="<%= path %>"
            /></path>
          <% end %>
        </g>
      </svg>

      <div class="chat">
        <div class="messages">
          <%= for message <- @messages do %>
            <%= case message do %>
              <%= {:text, user, message} -> %>
                <div class="message"><b><%= user %></b> <%= message %></div>
              <%= {:join, user} -> %>
                <div class="message system"><b><%= user %></b> joined the game</div>
              <%= {:leave, user} -> %>
                <div class="message system"><b><%= user %></b> left the game</div>
              <%= {:guess, user} -> %>
                <div class="message guess"><b><%= user %></b> guessed the word</div>
            <% end %>
          <% end %>
        </div>
        <form phx-submit="chat_send">
          <input type="text" name="message" />
          <button type="submit" class="btn">&raquo;</button>
        </form>
      </div>

      <div class="controls">
        <div class="panel colors">
          <a class="color" phx-click="color" phx-value="#fff" style="background: #fff;"></a>
          <a class="color" phx-click="color" phx-value="#ccc" style="background: #ccc;"></a>
          <a class="color" phx-click="color" phx-value="#f90b2b" style="background: #f90b2b;"></a>
          <a class="color" phx-click="color" phx-value="#ff712b" style="background: #ff712b;"></a>
          <a class="color" phx-click="color" phx-value="#ffdf28" style="background: #ffdf28;"></a>
          <a class="color" phx-click="color" phx-value="#00dd1d" style="background: #00dd1d;"></a>
          <a class="color" phx-click="color" phx-value="#06bafd" style="background: #06bafd;"></a>
          <a class="color" phx-click="color" phx-value="#b700c3" style="background: #b700c3;"></a>
          <a class="color" phx-click="color" phx-value="#e281a8" style="background: #e281a8;"></a>
          <a class="color" phx-click="color" phx-value="#ba6645" style="background: #ba6645;"></a>
          <br/>
          <a class="color" phx-click="color" phx-value="#000" style="background: #000;"></a>
          <a class="color" phx-click="color" phx-value="#444" style="background: #444;"></a>
          <a class="color" phx-click="color" phx-value="#761d1d" style="background: #761d1d;"></a>
          <a class="color" phx-click="color" phx-value="#ce3c15" style="background: #ce3c15;"></a>
          <a class="color" phx-click="color" phx-value="#f49e24" style="background: #f49e24;"></a>
          <a class="color" phx-click="color" phx-value="#005f0e" style="background: #005f0e;"></a>
          <a class="color" phx-click="color" phx-value="#0353a0" style="background: #0353a0;"></a>
          <a class="color" phx-click="color" phx-value="#580070" style="background: #580070;"></a>
          <a class="color" phx-click="color" phx-value="#ab648a" style="background: #ab648a;"></a>
          <a class="color" phx-click="color" phx-value="#7c4629" style="background: #7c4629;"></a>
        </div>

        <div class="panel sizes">
          <a class="btn size" phx-click="size" phx-value="5">5</a>
          <a class="btn size" phx-click="size" phx-value="10">10</a>
          <a class="btn size" phx-click="size" phx-value="15">15</a>
          <a class="btn size" phx-click="size" phx-value="20">20</a>
          <a class="btn size" phx-click="size" phx-value="30">30</a>
        </div>

        <div class="panel misc">
          <a class="btn clear" phx-click="clear">Clear</a>
        </div>
      </div>
    </div>
    """
  end

  def mount(_session, socket) do
    socket = socket
      |> assign(%{
          room_name: "default",
          room_pid: nil,
          mode: :draw,
          size: 5,
          color: "black",
          time_left: 0,
          messages: [],
          active_path: {"black", 5, "", []},
          paths: []
        })

    {:ok, socket}
  end

  def handle_params(%{"room" => room_name}, _url, socket) do
    if connected?(socket) do
      {:ok, room_pid} = Room.join(room_name, "Jet")

      socket = assign(socket,
        room_pid: room_pid,
        room_name: room_name
      )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "draw", payload: state}, socket) do
    {:noreply, assign(socket, :active_path, state.active_path)}
  end

  def handle_info(%{event: "drawend", payload: state}, socket) do
    socket = assign(socket,
      active_path: state.active_path,
      paths: state.paths
    )

    {:noreply, socket}
  end

  def handle_info(%{event: "clear"}, socket) do
    socket = assign(socket,
      active_path: {"black", 5, "", []},
      paths: []
    )

    {:noreply, socket}
  end

  def handle_info(%{event: "countdown", payload: payload}, socket) do
    {:noreply, assign(socket, time_left: payload.time_left)}
  end

  def handle_info(%{event: "end_round", payload: payload}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{event: "chat", payload: payload}, socket) do
    socket = assign(socket,
      messages: socket.assigns.messages ++ [payload.message]
    )

    {:noreply, socket}
  end

  def handle_info({:join_room, state}, socket) do
    socket = assign(socket,
      active_path: state.active_path,
      paths: state.paths
    )

    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  def terminate(reason, socket) do
    %{room_pid: room_pid} = socket.assigns

    Room.leave(room_pid)
    {:stop, reason}
  end

  def handle_event("drawstart", coords, socket) do
    %{ size: size, color: color, room_pid: room_pid } = socket.assigns

    active_path = {color, size, "", []}
      |> add_point(coords)
      |> draw_path()

    Room.draw(room_pid, active_path)

    {:noreply, assign(socket, :active_path, active_path)}
  end

  def handle_event("draw", coords, socket) do
    %{ active_path: active_path, room_pid: room_pid } = socket.assigns

    active_path = active_path
      |> add_point(coords)
      |> draw_path()

    Room.draw(room_pid, active_path)

    {:noreply, assign(socket, :active_path, active_path)}
  end

  def handle_event("drawend", _coords, socket) do
    %{ paths: paths, active_path: active_path, room_pid: room_pid } = socket.assigns

    Room.draw_end(room_pid)

    {:noreply, socket}
  end

  def handle_event("chat_send", %{"message" => message}, socket) do
    %{ room_pid: room_pid } = socket.assigns

    Room.chat_send(room_pid, message)

    {:noreply, socket}
  end

  def handle_event("color", color, socket) do
    {:noreply, assign(socket, :color, color)}
  end

  def handle_event("size", size, socket) do
    {:noreply, assign(socket, :size, size)}
  end

  def handle_event("clear", _, socket) do
    Room.clear(socket.assigns.room_pid)

    {:noreply, socket}
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  defp put_date(socket) do
    assign(socket, date: :calendar.local_time())
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
  defp add_point({col, size, path, [p1, p2 | points]}, %{"x" => x, "y" => y}) do
    dist = get_distance(p1, p2)

    if dist < @point_distance do
      {col, size, path, [{x, y}, p2 | points]}
    else
      {col, size, path, [{x, y}, p1, p2 | points]}
    end
  end

  defp add_point({col, size, path, []}, %{"x" => x, "y" => y}) do
    # Add point once for the M and L instructions respectively
    {col, size, path, [{x, y}, {x, y}]}
  end

  defp get_distance({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
  end
end
