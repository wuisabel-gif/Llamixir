defmodule Llamixir.Control.Client do
  @moduledoc "Client for the local Llamixir daemon control socket."

  alias Llamixir.Control.Server

  def ping(opts \\ []), do: request("ping", opts)

  def snapshots(opts \\ []) do
    with {:ok, %{"ok" => true, "snapshots" => snapshots}} <- request("snapshots", opts) do
      {:ok, Enum.map(snapshots, &decode_snapshot/1)}
    end
  end

  def request(command, opts \\ []) do
    path = Keyword.get(opts, :path, Server.socket_path())
    timeout = Keyword.get(opts, :timeout, 250)

    case :gen_tcp.connect(
           {:local, path},
           0,
           [:binary, packet: :line, active: false],
           timeout
         ) do
      {:ok, socket} -> request_on_socket(socket, command, timeout)
      {:error, reason} -> {:error, reason}
    end
  end

  defp request_on_socket(socket, command, timeout) do
    try do
      with :ok <- :gen_tcp.send(socket, JSON.encode!(%{"command" => command}) <> "\n"),
           {:ok, line} <- :gen_tcp.recv(socket, 0, timeout),
           {:ok, response} <- JSON.decode(String.trim(line)) do
        {:ok, response}
      else
        {:error, reason} -> {:error, reason}
      end
    after
      :gen_tcp.close(socket)
    end
  end

  defp decode_snapshot(snapshot) do
    %{
      id: decode_runtime(Map.fetch!(snapshot, "id")),
      status: decode_status(Map.fetch!(snapshot, "status")),
      models: Enum.map(Map.get(snapshot, "models", []), &decode_model/1),
      running_models: Enum.map(Map.get(snapshot, "running_models", []), &decode_running_model/1),
      error: Map.get(snapshot, "error")
    }
  end

  defp decode_model(model) do
    %{
      name: Map.fetch!(model, "name"),
      size: Map.get(model, "size"),
      modified_at: Map.get(model, "modified_at"),
      metadata: Map.get(model, "metadata", %{})
    }
  end

  defp decode_running_model(model) do
    %{
      name: Map.fetch!(model, "name"),
      size: Map.get(model, "size"),
      vram_size: Map.get(model, "vram_size"),
      expires_at: Map.get(model, "expires_at"),
      metadata: Map.get(model, "metadata", %{})
    }
  end

  defp decode_runtime("ollama"), do: :ollama
  defp decode_runtime("llamacpp"), do: :llamacpp
  defp decode_runtime(runtime), do: runtime

  defp decode_status("ready"), do: :ready
  defp decode_status("unavailable"), do: :unavailable
  defp decode_status("error"), do: :error
  defp decode_status("starting"), do: :starting
  defp decode_status(status), do: status
end
