defmodule Llamixir.CLITest do
  use ExUnit.Case, async: true

  test "renders model inventory as an aligned table" do
    models = [
      %{
        name: "qwen2.5:0.5b",
        size: 397_000_000,
        modified_at: "2026-07-21",
        metadata: %{"family" => "qwen2"}
      },
      %{name: "llama3:8b", size: 5_000_000_000, modified_at: nil, metadata: %{}}
    ]

    table = Llamixir.CLI.render_models(models)

    assert table =~ "MODEL"
    assert table =~ "RUNTIME"
    assert table =~ "llama3:8b"
    assert table =~ "4.7 GB"
    assert table =~ "qwen2"
  end

  test "renders an empty inventory clearly" do
    assert Llamixir.CLI.render_models([]) == "No models installed."
  end

  test "renders loaded-model memory usage" do
    models = [
      %{
        runtime: :ollama,
        name: "qwen2.5:0.5b",
        size: 397_000_000,
        vram_size: 250_000_000,
        expires_at: "2026-07-21T01:00:00Z"
      }
    ]

    table = Llamixir.CLI.render_running_models(models)
    assert table =~ "VRAM"
    assert table =~ "238.4 MB"
    assert table =~ "ollama"
  end

  test "renders runtime health summaries" do
    snapshots = [
      %{id: :ollama, status: :ready, models: [%{}], running_models: [%{}], error: nil},
      %{
        id: :llamacpp,
        status: :error,
        models: [],
        running_models: [],
        error: {:http_status, 404}
      }
    ]

    table = Llamixir.CLI.render_runtimes(snapshots)
    assert table =~ "ollama"
    assert table =~ "llamacpp"
    assert table =~ "HTTP 404"
  end

  test "status succeeds only when every runtime is ready" do
    ready = %{id: :ollama, status: :ready, models: [], running_models: [], error: nil}
    failed = %{ready | id: :llamacpp, status: :unavailable}

    assert Llamixir.CLI.status_exit_code([ready]) == 0
    assert Llamixir.CLI.status_exit_code([ready, failed]) == 1
    assert Llamixir.CLI.status_exit_code([]) == 1
  end
end
