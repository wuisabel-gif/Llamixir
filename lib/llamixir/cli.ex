defmodule Llamixir.CLI do
  @moduledoc "Command-line entry point for Llamixir."

  alias Llamixir.Runtime.{LlamaCpp, Ollama, Supervisor, Worker}

  @version Mix.Project.config()[:version]

  def main(args) do
    {:ok, _started} = Application.ensure_all_started(:llamixir)

    case args do
      [] ->
        dashboard()

      ["status"] ->
        status()

      ["models"] ->
        models(nil)

      ["models", runtime] ->
        models(runtime)

      ["running"] ->
        running()

      ["daemon"] ->
        daemon()

      ["version"] ->
        IO.puts("llamixir #{@version}")

      [command] when command in ["help", "--help", "-h"] ->
        help()

      _ ->
        help(:stderr)
        System.halt(1)
    end
  end

  defp dashboard do
    snapshots = runtime_snapshots()

    IO.puts("Llamixir — supervised local AI runtimes\n")
    IO.puts(render_runtimes(snapshots))
  end

  defp status do
    runtime_snapshots()
    |> Enum.each(fn snapshot ->
      IO.puts(
        "#{snapshot.id}\t#{snapshot.status}\t#{length(snapshot.models)} models\t#{length(snapshot.running_models)} running"
      )
    end)
  end

  defp models(runtime) do
    with {:ok, snapshots} <- select_runtimes(runtime) do
      models =
        for snapshot <- snapshots,
            snapshot.status == :ready,
            model <- snapshot.models do
          Map.put(model, :runtime, snapshot.id)
        end

      IO.puts(render_models(models))
    else
      {:error, message} ->
        IO.puts(:stderr, message)
        System.halt(1)
    end
  end

  defp running do
    models =
      for snapshot <- runtime_snapshots(),
          snapshot.status == :ready,
          model <- snapshot.running_models do
        Map.put(model, :runtime, snapshot.id)
      end

    IO.puts(render_running_models(models))
  end

  defp daemon do
    snapshots = runtime_snapshots()
    IO.puts("Llamixir daemon started with #{length(snapshots)} supervised runtimes.")
    IO.puts(render_runtimes(snapshots))
    Process.sleep(:infinity)
  end

  @doc false
  def render_models([]), do: "No models installed."

  def render_models(models) do
    rows =
      models
      |> Enum.sort_by(&String.downcase(&1.name))
      |> Enum.map(fn model ->
        [
          to_string(Map.get(model, :runtime, "—")),
          model.name,
          format_bytes(Map.get(model, :size)),
          model_family(model),
          Map.get(model, :modified_at) || "—"
        ]
      end)

    render_table(["RUNTIME", "MODEL", "SIZE", "FAMILY", "MODIFIED"], rows)
  end

  @doc false
  def render_running_models([]), do: "No models are currently loaded."

  def render_running_models(models) do
    rows =
      models
      |> Enum.sort_by(&String.downcase(&1.name))
      |> Enum.map(fn model ->
        [
          to_string(Map.get(model, :runtime, "—")),
          model.name,
          format_bytes(Map.get(model, :size)),
          format_bytes(Map.get(model, :vram_size)),
          Map.get(model, :expires_at) || "—"
        ]
      end)

    render_table(["RUNTIME", "MODEL", "SIZE", "VRAM", "EXPIRES"], rows)
  end

  @doc false
  def render_runtimes(snapshots) do
    rows =
      Enum.map(snapshots, fn snapshot ->
        [
          to_string(snapshot.id),
          to_string(snapshot.status),
          to_string(length(snapshot.models)),
          to_string(length(snapshot.running_models))
        ]
      end)

    render_table(["RUNTIME", "STATUS", "MODELS", "RUNNING"], rows)
  end

  defp runtime_snapshots do
    ensure_runtimes()
    Enum.map(runtime_specs(), fn {id, _adapter, _config} -> Worker.snapshot(Worker.via(id)) end)
  end

  defp ensure_runtimes do
    Enum.each(runtime_specs(), fn {id, adapter, config} ->
      case Supervisor.start_runtime(id, adapter, config) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end
    end)
  end

  defp select_runtimes(nil), do: {:ok, runtime_snapshots()}

  defp select_runtimes(runtime) do
    case Enum.find(runtime_snapshots(), &(to_string(&1.id) == runtime)) do
      nil -> {:error, "Unknown runtime: #{runtime}"}
      snapshot -> {:ok, [snapshot]}
    end
  end

  defp runtime_specs do
    [
      {:ollama, Ollama, url: ollama_url(), refresh_interval: 5_000},
      {:llamacpp, LlamaCpp, url: llama_cpp_url(), refresh_interval: 5_000}
    ]
  end

  defp ollama_url do
    System.get_env("LLAMIXIR_OLLAMA_URL", "http://127.0.0.1:11434")
  end

  defp llama_cpp_url do
    System.get_env("LLAMIXIR_LLAMA_CPP_URL", "http://127.0.0.1:8080")
  end

  defp model_family(%{metadata: %{"family" => family}}), do: family
  defp model_family(_model), do: "—"

  defp format_bytes(bytes) when is_integer(bytes) and bytes >= 1_073_741_824,
    do: format_unit(bytes / 1_073_741_824, "GB")

  defp format_bytes(bytes) when is_integer(bytes) and bytes >= 1_048_576,
    do: format_unit(bytes / 1_048_576, "MB")

  defp format_bytes(bytes) when is_integer(bytes), do: "#{bytes} B"
  defp format_bytes(_bytes), do: "—"

  defp format_unit(value, unit), do: :erlang.float_to_binary(value, decimals: 1) <> " " <> unit

  defp render_table(headers, rows) do
    widths =
      [headers | rows]
      |> Enum.zip_with(fn column -> column |> Enum.map(&String.length/1) |> Enum.max() end)

    [headers | rows]
    |> Enum.map_join("\n", fn row ->
      row
      |> Enum.zip(widths)
      |> Enum.map_join("  ", fn {value, width} -> String.pad_trailing(value, width) end)
    end)
  end

  defp help(device \\ :stdio) do
    IO.puts(device, """
    Llamixir — supervised local AI runtimes

    Usage:
      llamixir             Show the runtime dashboard
      llamixir status      Show runtime health
      llamixir models      List models across healthy runtimes
      llamixir models NAME List models from one runtime
      llamixir running     Show loaded models and memory usage
      llamixir daemon      Run continuous supervision in the foreground
      llamixir version     Print the version
      llamixir help        Show this help

    Environment:
      LLAMIXIR_OLLAMA_URL  Ollama API URL (default: http://127.0.0.1:11434)
      LLAMIXIR_LLAMA_CPP_URL
                           llama.cpp URL (default: http://127.0.0.1:8080)
    """)
  end
end
