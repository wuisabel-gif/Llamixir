defmodule Llamixir do
  @moduledoc """
  Public API for supervised local AI runtime state.
  """

  alias Llamixir.Runtime.Supervisor

  @doc "Returns the latest snapshot for every supervised runtime."
  def snapshots, do: Supervisor.snapshots()

  @doc "Returns installed models across all runtimes or one runtime."
  def models(runtime \\ :all), do: inventory(:models, runtime)

  @doc "Returns loaded models across all runtimes or one runtime."
  def running_models(runtime \\ :all), do: inventory(:running_models, runtime)

  defp inventory(field, runtime) do
    snapshots()
    |> Enum.filter(&(runtime == :all or to_string(&1.id) == to_string(runtime)))
    |> Enum.flat_map(fn snapshot ->
      Enum.map(Map.fetch!(snapshot, field), &Map.put(&1, :runtime, snapshot.id))
    end)
  end
end
