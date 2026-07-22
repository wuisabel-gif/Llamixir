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
    assert table =~ "llama3:8b"
    assert table =~ "4.7 GB"
    assert table =~ "qwen2"
  end

  test "renders an empty inventory clearly" do
    assert Llamixir.CLI.render_models([]) == "No models installed."
  end
end
