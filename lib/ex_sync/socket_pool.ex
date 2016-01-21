defmodule ExSync.SocketPool do
  use Supervisor

  @pool_name :diffsync_poolboy

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    pool_opts = [
      name: {:local, @pool_name},
      worker_module: Exsync.JSONDPSocketAdapter,
      size: 10,
      max_overflow: 1000,
    ]

    children = [
      :poolboy.child_spec(@pool_name, pool_opts, [])
    ]

    supervise(children, strategy: :one_for_one, name: __MODULE__)
  end

  def patch(doc, edit) do
    :poolboy.transaction @pool_name, fn(socket_adapter) ->
      Exsync.JSONDPSocketAdapter.patch(doc, edit, socket_adapter)
    end
  end

  def diff(origin, new) do
    :poolboy.transaction @pool_name, fn(socket_adapter) ->
      Exsync.JSONDPSocketAdapter.diff(origin, new, socket_adapter)
    end
  end
end
