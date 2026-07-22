defmodule Llamixir.Runtime.WorkerTest do
  use ExUnit.Case, async: false

  defmodule HealthyAdapter do
    @behaviour Llamixir.Runtime.Adapter

    @impl true
    def health(_config), do: :ready

    @impl true
    def models(_config), do: {:ok, [%{name: "qwen-test", size: 42}]}
  end

  defmodule FailedAdapter do
    @behaviour Llamixir.Runtime.Adapter

    @impl true
    def health(_config), do: {:error, :connection_refused}

    @impl true
    def models(_config), do: {:ok, []}
  end

  test "reports health and discovered models" do
    id = unique_id(:healthy)
    assert {:ok, _pid} = start_runtime(id, HealthyAdapter)

    assert %{id: ^id, status: :ready, models: [%{name: "qwen-test", size: 42}]} =
             Llamixir.Runtime.Worker.snapshot(Llamixir.Runtime.Worker.via(id))
  end

  test "keeps adapter failures observable without crashing" do
    id = unique_id(:failed)
    assert {:ok, pid} = start_runtime(id, FailedAdapter)

    assert %{status: :error, error: :connection_refused} =
             Llamixir.Runtime.Worker.snapshot(pid)

    assert Process.alive?(pid)
  end

  test "lists supervised runtime snapshots" do
    id = unique_id(:listed)

    assert {:ok, _pid} =
             Llamixir.Runtime.Supervisor.start_runtime(id, HealthyAdapter,
               refresh_interval: 60_000
             )

    on_exit(fn -> Llamixir.Runtime.Supervisor.stop_runtime(id) end)

    assert Enum.any?(Llamixir.Runtime.Supervisor.snapshots(), &(&1.id == id))
  end

  test "restarts a runtime worker after an unexpected crash" do
    id = unique_id(:recovered)

    assert {:ok, original_pid} =
             Llamixir.Runtime.Supervisor.start_runtime(id, HealthyAdapter,
               refresh_interval: 60_000
             )

    on_exit(fn -> Llamixir.Runtime.Supervisor.stop_runtime(id) end)
    Process.exit(original_pid, :kill)

    replacement_pid = wait_for_replacement(id, original_pid)
    assert is_pid(replacement_pid)
    assert Process.alive?(replacement_pid)

    assert %{status: :ready, models: [%{name: "qwen-test"}]} =
             Llamixir.Runtime.Worker.snapshot(replacement_pid)
  end

  defp start_runtime(id, adapter) do
    start_supervised({Llamixir.Runtime.Worker, id: id, adapter: adapter})
  end

  defp unique_id(prefix), do: String.to_atom("#{prefix}_#{System.unique_integer([:positive])}")

  defp wait_for_replacement(id, original_pid, attempts \\ 20)

  defp wait_for_replacement(_id, _original_pid, 0), do: nil

  defp wait_for_replacement(id, original_pid, attempts) do
    case Registry.lookup(Llamixir.Runtime.Registry, id) do
      [{pid, _value}] when pid != original_pid ->
        pid

      _other ->
        Process.sleep(10)
        wait_for_replacement(id, original_pid, attempts - 1)
    end
  end
end
