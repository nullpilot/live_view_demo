defmodule LiveViewDemoWeb.ClockLive do
  use Phoenix.LiveView
  import Calendar.Strftime

  def render(assigns) do
    ~L"""
    <div>
      <svg class="drawing" xmlns="http://www.w3.org/2000/svg"
        phx-mousedown="drawstart"
        phx-mouseup="drawend"
        phx-mousemove="draw"
      >
        <text><%= strftime!(@date, "%r") %></text>

        <g shape-rendering="crispEdges">
          <%= for {_col, _size, path} <- @paths do %>
            <path fill="none" stroke="red"
              d="<%= path %>" />
          <% end %>

          <path fill="none" stroke="red"
              d="<%= elem(@active_path, 2) %>" />
        </g>
      </svg> 
    </div>
    """
  end

  def mount(_session, socket) do
    if connected?(socket), do: :timer.send_interval(1000, self(), :tick)

    socket = socket
      |> assign(%{
          mode: :draw,
          size: 1,
          color: 0,
          active_path: {0, 1, ""},
          paths: [
            {0, 1, "M 10,100 L 100,100 z"},
            {0, 1, "M 10,50 L 100,50 z"}
          ]
        })
      |> put_date

    {:ok, socket}
  end

  def handle_info(:tick, socket) do
    {:noreply, put_date(socket)}
  end

  def handle_event("drawstart", _coords, %{assigns: assigns} = socket) do
    %{ size: size, color: color } = assigns

    {:noreply, assign(socket, :active_path, {color, size, ""})}
  end

  def handle_event("draw", coords, %{assigns: assigns} = socket) do
    {col, size, d} = assigns.active_path
    d = append_path(d, coords)

    {:noreply, assign(socket, :active_path, {col, size, d})}
  end

  def handle_event("drawend", _coords, %{assigns: assigns} = socket) do
    socket = socket
      |> assign(:paths, assigns.paths ++ [assigns.active_path])
      |> assign(:active_path, {0, 1, ""})

    {:noreply, socket}
  end

  defp put_date(socket) do
    assign(socket, date: :calendar.local_time())
  end

  defp append_path("", %{"x" => x, "y" => y}) do
    "M " <> Kernel.inspect(x) <> "," <> Kernel.inspect(y)
  end

  defp append_path(d, %{"x" => x, "y" => y}) do
    d <> " L " <> Kernel.inspect(x) <> "," <> Kernel.inspect(y)
  end
end
