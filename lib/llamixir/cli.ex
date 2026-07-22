defmodule Llamixir.CLI do
  @moduledoc "Command-line entry point for Llamixir."

  alias Llamixir.Runtime.{Ollama, Supervisor, Worker}

  @version Mix.Project.config()[:version]

  def main(args) do
    {:ok, _started} = Application.ensure_all_started(:llamixir)

    case args do
      [] ->
        dashboard()

      ["status"] ->
        status()

      ["models"] ->
        models()

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
    snapshot = ollama_snapshot()

    IO.puts("Llamixir — supervised local AI runtimes\n")
    IO.puts("RUNTIME    STATUS       MODELS")
    IO.puts("ollama     #{pad(snapshot.status, 12)} #{length(snapshot.models)}")

    if snapshot.status == :ready do
      IO.puts("\n" <> render_models(snapshot.models))
    else
      IO.puts("\nOllama is unavailable at #{ollama_url()}.")
    end
  end

  defp status do
    snapshot = ollama_snapshot()
    IO.puts("ollama\t#{snapshot.status}\t#{length(snapshot.models)} models")
  end

  defp models do
    snapshot = ollama_snapshot()

    if snapshot.status == :ready do
      IO.puts(render_models(snapshot.models))
    else
      IO.puts(:stderr, "Ollama is unavailable at #{ollama_url()}")
      System.halt(1)
    end
  end

  @doc false
  def render_models([]), do: "No models installed."

  def render_models(models) do
    rows =
      models
      |> Enum.sort_by(&String.downcase(&1.name))
      |> Enum.map(fn model ->
        [model.name, format_bytes(model.size), model_family(model), model.modified_at || "—"]
      end)

    widths =
      [["MODEL", "SIZE", "FAMILY", "MODIFIED"] | rows]
      |> Enum.zip_with(fn column -> column |> Enum.map(&String.length/1) |> Enum.max() end)

    [["MODEL", "SIZE", "FAMILY", "MODIFIED"] | rows]
    |> Enum.map_join("\n", fn row ->
      row
      |> Enum.zip(widths)
      |> Enum.map_join("  ", fn {value, width} -> String.pad_trailing(value, width) end)
    end)
  end

  defp ollama_snapshot do
    case Supervisor.start_runtime(:ollama, Ollama, url: ollama_url(), refresh_interval: 5_000) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    Worker.refresh(Worker.via(:ollama))
  end

  defp ollama_url do
    System.get_env("LLAMIXIR_OLLAMA_URL", "http://127.0.0.1:11434")
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
  defp pad(value, width), do: value |> to_string() |> String.pad_trailing(width)

  defp help(device \\ :stdio) do
    IO.puts(device, """
    Llamixir — supervised local AI runtimes

    Usage:
      llamixir             Show the runtime dashboard
      llamixir status      Show runtime health
      llamixir models      List discovered Ollama models
      llamixir version     Print the version
      llamixir help        Show this help

    Environment:
      LLAMIXIR_OLLAMA_URL  Ollama API URL (default: http://127.0.0.1:11434)
    """)
  end
end
