defmodule LiveViewDemoWeb.DrawLive do
  use Phoenix.LiveView
  import Calendar.Strftime

  alias LiveViewDemoWeb.Endpoint, as: PubSub
  alias LiveViewDemo.Room

  @point_distance 16

  def render(assigns) do
    ~L"""
    <div class="game">
      <svg class="drawing" xmlns="http://www.w3.org/2000/svg"
        phx-mousedown="drawstart"
        phx-mouseup="drawend"
        phx-mousemove="draw"
        width="600"
        height="400"
        viewBox="0 0 600 400"
      >
        <text><%= strftime!(@date, "%r") %></text>

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

      <div class="controls">
        <div class="modes">
          <a>Draw</a>
        </div>

        <div class="colors">
          <a class="color" phx-click="color" phx-value="yellow" style="background: yellow;"></a>
          <a class="color" phx-click="color" phx-value="red" style="background: red;"></a>
          <a class="color" phx-click="color" phx-value="lime" style="background: lime;"></a>
          <a class="color" phx-click="color" phx-value="blue" style="background: blue;"></a>
        </div>

        <div class="sizes">
          <a class="size" phx-click="size" phx-value="5">5</a>
          <a class="size" phx-click="size" phx-value="10">15</a>
          <a class="size" phx-click="size" phx-value="15">15</a>
          <a class="size" phx-click="size" phx-value="20">20</a>
          <a class="size" phx-click="size" phx-value="30">30</a>
        </div>

        <a class="clear" phx-click="clear">Clear</a>
      </div>
    </div>
    """
  end

  def mount(_session, socket) do
    if connected?(socket) do
      :timer.send_interval(1000, self(), :tick)
    end

    socket = socket
      |> assign(%{
          room_name: "default",
          room_pid: nil,
          mode: :draw,
          size: 5,
          color: "black",
          active_path: {"black", 5, "", []},
          paths: []
        })
      |> put_date

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

  def handle_info(:tick, socket) do
    {:noreply, put_date(socket)}
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
      |> add_initial_point(coords)
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

  defp add_initial_point(active_path, %{"x" => x, "y" => y}) do
    # Add point once for the M and L instructions respectively
    active_path
      |> put_elem(3, [{x, y}, {x, y}])
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

  defp get_distance({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
  end
end
