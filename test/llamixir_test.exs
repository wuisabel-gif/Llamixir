defmodule LlamixirTest do
  use ExUnit.Case, async: false

  defmodule Adapter do
    @behaviour Llamixir.Runtime.Adapter

    @impl true
    def probe(_config) do
      {:ok,
       %{
         models: [%{name: "public-api-model"}],
         running_models: [%{name: "public-api-model", vram_size: 42}]
       }}
    end
  end

  test "exposes supervised inventory through the public API" do
    id = String.to_atom("public_api_#{System.unique_integer([:positive])}")

    assert {:ok, pid} =
             Llamixir.Runtime.Supervisor.start_runtime(id, Adapter, refresh_interval: 60_000)

    on_exit(fn -> Llamixir.Runtime.Supervisor.stop_runtime(id) end)
    assert %{status: :ready} = Llamixir.Runtime.Worker.refresh(pid)

    assert [%{name: "public-api-model", runtime: ^id}] = Llamixir.models(id)
    assert [%{name: "public-api-model", runtime: ^id}] = Llamixir.running_models(id)
    assert Enum.any?(Llamixir.snapshots(), &(&1.id == id))
  end
end
