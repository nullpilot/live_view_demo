defmodule LiveViewDemoWeb.ClockLive do
  use Phoenix.LiveView
  import Calendar.Strftime

  def render(assigns) do
    ~L"""
    <div>
      <svg xmlns="http://www.w3.org/2000/svg">
        <text><%= strftime!(@date, "%r") %></text>
      </svg> 
    </div>
    """
  end

  def mount(_session, socket) do
    if connected?(socket), do: :timer.send_interval(1000, self(), :tick)

    {:ok, put_date(socket)}
  end

  def handle_info(:tick, socket) do
    {:noreply, put_date(socket)}
  end

  defp put_date(socket) do
    assign(socket, date: :calendar.local_time())
  end
end
