defmodule LiveViewDemoWeb.PageLiveTest do
  use LiveViewDemoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "How to play"
    assert render(page_live) =~ "How to play"
  end
end
