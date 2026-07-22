defmodule Llamixir.Control.Server do
  @moduledoc "Local Unix-socket control server for the Llamixir daemon."

  use GenServer

  @protocol_version 1

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def socket_path do
    System.get_env("LLAMIXIR_SOCKET") ||
      Path.join(
        System.get_env("XDG_STATE_HOME", Path.expand("~/.local/state")),
        "llamixir/control.sock"
      )
  end

  @impl true
  def init(opts) do
    path = Keyword.get(opts, :path, socket_path())
    File.mkdir_p!(Path.dirname(path))

    with :ok <- prepare_socket(path),
         {:ok, listener} <-
           :gen_tcp.listen(0, [
             :binary,
             packet: :line,
             active: false,
             ifaddr: {:local, path}
           ]) do
      acceptor = spawn_link(fn -> accept_loop(listener) end)
      {:ok, %{listener: listener, acceptor: acceptor, path: path}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, state) do
    :gen_tcp.close(state.listener)
    File.rm(state.path)
    :ok
  end

  defp prepare_socket(path) do
    case :gen_tcp.connect({:local, path}, 0, [:binary, active: false], 100) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        {:error, :daemon_already_running}

      {:error, _reason} ->
        File.rm(path)
        :ok
    end
  end

  defp accept_loop(listener) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        serve(socket)
        accept_loop(listener)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        exit(reason)
    end
  end

  defp serve(socket) do
    response =
      case :gen_tcp.recv(socket, 0, 2_000) do
        {:ok, line} -> line |> String.trim() |> decode_request() |> handle_request()
        {:error, reason} -> error_response("receive_failed", inspect(reason))
      end

    :gen_tcp.send(socket, JSON.encode!(response) <> "\n")
    :gen_tcp.close(socket)
  end

  defp decode_request(line) do
    case JSON.decode(line) do
      {:ok, request} when is_map(request) -> {:ok, request}
      {:ok, _value} -> {:error, "request_must_be_an_object"}
      {:error, _reason} -> {:error, "invalid_json"}
    end
  end

  defp handle_request({:ok, %{"command" => "ping"}}) do
    %{"ok" => true, "protocol" => @protocol_version}
  end

  defp handle_request({:ok, %{"command" => "snapshots"}}) do
    %{
      "ok" => true,
      "protocol" => @protocol_version,
      "snapshots" => normalize(Llamixir.Runtime.Supervisor.snapshots())
    }
  end

  defp handle_request({:ok, %{"command" => command}}),
    do: error_response("unknown_command", command)

  defp handle_request({:ok, _request}), do: error_response("missing_command", nil)
  defp handle_request({:error, reason}), do: error_response(reason, nil)

  defp error_response(code, detail) do
    %{"ok" => false, "protocol" => @protocol_version, "error" => code, "detail" => detail}
  end

  defp normalize(value) when is_list(value), do: Enum.map(value, &normalize/1)

  defp normalize(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {to_string(key), normalize(nested)} end)
  end

  defp normalize(value) when is_tuple(value), do: inspect(value)
  defp normalize(value) when is_atom(value) and not is_nil(value), do: to_string(value)
  defp normalize(value), do: value
end
