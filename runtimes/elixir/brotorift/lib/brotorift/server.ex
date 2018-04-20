defmodule Brotorift.Server do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def stop(server) do
    GenServer.stop(server)
  end

  def init(args) do
    port = Keyword.fetch!(args, :port)
    :ranch.start_listener(__MODULE__, :ranch_tcp, [{:port, port}], Brotorift.RanchProtocol, [])
  end

  def terminate(_reason, ranch_server) do
    :ok = :ranch.stop_listener(ranch_server)
  end
end
