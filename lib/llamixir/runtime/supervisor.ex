defmodule Llamixir.Runtime.Supervisor do
  @moduledoc "Supervises dynamically configured local AI runtimes."

  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts), do: DynamicSupervisor.init(strategy: :one_for_one)

  def start_runtime(id, adapter, config \\ []) do
    spec = {Llamixir.Runtime.Worker, id: id, adapter: adapter, config: config}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_runtime(id) do
    case Registry.lookup(Llamixir.Runtime.Registry, id) do
      [{pid, _value}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end

  def snapshots do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_id, pid, _type, _modules} -> Llamixir.Runtime.Worker.snapshot(pid) end)
    |> Enum.sort_by(& &1.id)
  end
end
