defmodule GlificWeb.Providers.Gupshup.Controllers.DefaultController do
  @moduledoc false

  use GlificWeb, :controller

  @doc false
  @spec handler(Plug.Conn.t(), map(), String.t()) :: Plug.Conn.t()
  def handler(conn, _params, _msg) do
    conn
    |> Plug.Conn.send_resp(200, "")
    |> Plug.Conn.halt()
  end

  @doc false
  @spec unknown(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unknown(conn, params),
    do: handler(conn, params, "unknown handler")
end
