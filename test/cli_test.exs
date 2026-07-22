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
      %{id: :ollama, status: :ready, models: [%{}], running_models: [%{}]},
      %{id: :llamacpp, status: :unavailable, models: [], running_models: []}
    ]

    table = Llamixir.CLI.render_runtimes(snapshots)
    assert table =~ "ollama"
    assert table =~ "llamacpp"
    assert table =~ "unavailable"
  end
end
