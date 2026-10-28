defmodule FskickWeb.Plugs.HealthTest do
  use FskickWeb.ConnCase, async: true

  describe "GET /health/live" do
    test "returns 200", %{conn: conn} do
      conn = get(conn, "/health/live")
      assert response(conn, 200) == "ok"
    end
  end

  describe "GET /health/ready" do
    test "returns 200 when the database answers", %{conn: conn} do
      conn = get(conn, "/health/ready")
      assert response(conn, 200) == "ok"
    end
  end

  describe "other paths" do
    test "pass through to the router", %{conn: conn} do
      conn = get(conn, "/health/unknown")
      assert conn.status == 404
    end
  end
end
