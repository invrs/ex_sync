defmodule DiffSync.JSONDPSocketAdapter do
  use Connection

  alias :gen_tcp, as: TCP
  require Logger

  @conn_timeout 5_000
  @recv_timeout 5_000

  def patch(doc, edit, socket \\ __MODULE__) do
    rpc :patch, [doc, edit], 0, socket
  end

  def diff(origin, new, socket \\ __MODULE__) do
    rpc :diff, [origin, new], 0, socket
  end

  defp rpc(method, params, retry_count, socket) do
    GenServer.call(socket, {:send, method, params}, 100_000)
    |> handle
    |> case do
      result = {:ok, _}           -> result
      _error when retry_count < 5 -> rpc(method, params, retry_count + 1, socket)
      error                       -> error
    end
  end

  defp handle({:ok, reply = %{"error" => nil}}) do
    {:ok, reply["result"]}
  end
  defp handle({:ok, %{"error" => error}}) do
    Logger.error "JSONDP errored:"
    Logger.error "#{inspect error}"
    {:error, :jsondp_error}
  end
  defp handle({:error, error}) do
    Logger.error "RPC Connection to node resulted in an error:"
    Logger.error "#{inspect error}"
    {:error, :jsondp_connection_error}
  end

  # Server

  def start_link(supervisor_opts \\ [], connection_opts \\ []) do
    opts = Keyword.put_new(connection_opts, :timeout, @conn_timeout)
    args = Tuple.append(get_address, opts)

    Connection.start_link(__MODULE__, args, supervisor_opts)
  end

  def init({host, port, opts}) do
    state = %{host: host, port: port, opts: opts, socket: nil}
    {:connect, :init, state}
  end

  def connect(_, state = %{host: host, port: port, opts: opts}) do
    timeout = Keyword.fetch!(opts, :timeout)
    opts    = [:binary, active: false] ++ Keyword.delete(opts, :timeout)

    case TCP.connect(host, port, opts, timeout) do
      {:ok, socket} ->
        :timer.send_interval 10_000, :ping

        {:ok, put_in(state.socket, socket)}
      {:error, _}   -> {:backoff, 1_000, state}
    end
  end

  def disconnect(info, state = %{socket: socket}) do
    :ok = TCP.close(socket)

    case info do
      {:close, from} ->
        Connection.reply(from, :ok)

      {:error, reason} ->
        Logger.error "JSONDP Connection disconnected: #{reason}"
    end
    {:connect, :reconnect, put_in(state.socket, nil)}
  end

  def handle_call(_, _, state = %{socket: nil}) do
    {:reply, {:error, :closed}, state}
  end
  def handle_call({:send, method, params}, _from, state = %{socket: socket}) do
    payload =
      Poison.encode! %{
        id: Ecto.UUID.generate,
        method: method,
        params: params
      }

    case TCP.send(socket, payload <> <<0, 0>>) do
      :ok ->
        case recv_all(socket) do
          {:ok, data}         ->
            IO.inspect data
            {:reply, {:ok, Poison.decode!(data)}, state}

          {:error, _} = error ->
            {:disconnect, error, error, state}
        end

      {:error, _} = error ->
        {:disconnect, error, error, state}
    end
  end

  def handle_info(:ping, state) do
    case handle_call({:send, :ping, nil}, nil, state) do
      {:reply, {:ok, %{"result" => "pong"}}, state} ->
        {:noreply, state}

      other ->
        IO.inspect other
        {:disconnect, {:error, :ping_failed}, state}
    end
  end

  defp recv_all(socket, data \\ "") do
    case String.slice(data, -2, 2) do
      <<0, 0>> -> {:ok, String.slice(data, 0..-3)}
      _else ->
        case TCP.recv(socket, 0, @recv_timeout) do
          {:ok, new_data} -> recv_all(socket, data <> new_data)
          error           -> error
        end
    end
  end

  defp get_address do
    System.get_env("JSONDP_URL")
    |> URI.parse
    |> case do
      %{host: host, port: port} ->
        host
        |> String.to_char_list
        |> :inet.parse_ipv4_address
        |> case do
          {:ok, erl_ip}     -> {erl_ip, port}
          {:error, :einval} -> {String.to_char_list(host), port}
        end
    end
  end
end
