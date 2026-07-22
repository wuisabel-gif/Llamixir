defmodule Llamixir.Runtime.Worker do
  @moduledoc """
  Supervised state holder for one AI runtime.

  A worker periodically asks its adapter for health and model inventory. Failed
  checks are represented as state instead of crashing the supervision tree.
  """

  use GenServer

  @default_refresh_interval 5_000

  defstruct [:id, :adapter, :config, :timer, status: :starting, models: [], error: nil]

  @type state :: %__MODULE__{
          id: atom(),
          adapter: module(),
          config: keyword(),
          timer: {reference(), reference()} | nil,
          status: :starting | Llamixir.Runtime.Adapter.health(),
          models: [Llamixir.Runtime.Adapter.model()],
          error: term() | nil
        }

  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: via(id))
  end

  def snapshot(server), do: GenServer.call(server, :snapshot)
  def refresh(server), do: GenServer.call(server, :refresh)

  def via(id), do: {:via, Registry, {Llamixir.Runtime.Registry, id}}

  @impl true
  def init(opts) do
    state = %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      adapter: Keyword.fetch!(opts, :adapter),
      config: Keyword.get(opts, :config, [])
    }

    {:ok, state, {:continue, :refresh}}
  end

  @impl true
  def handle_continue(:refresh, state) do
    {:noreply, refresh_state(state) |> schedule_refresh()}
  end

  @impl true
  def handle_call(:snapshot, _from, state), do: {:reply, public_snapshot(state), state}

  def handle_call(:refresh, _from, state) do
    refreshed = state |> cancel_refresh() |> refresh_state() |> schedule_refresh()
    {:reply, public_snapshot(refreshed), refreshed}
  end

  @impl true
  def handle_info({:refresh, token}, %{timer: {_timer, token}} = state) do
    {:noreply, refresh_state(state) |> schedule_refresh()}
  end

  def handle_info({:refresh, _stale_token}, state), do: {:noreply, state}

  defp refresh_state(%{adapter: adapter, config: config} = state) do
    case adapter.health(config) do
      :ready -> refresh_models(%{state | status: :ready, error: nil})
      :unavailable -> %{state | status: :unavailable, models: [], error: nil}
      {:error, reason} -> %{state | status: :error, models: [], error: reason}
    end
  end

  defp refresh_models(%{adapter: adapter, config: config} = state) do
    case adapter.models(config) do
      {:ok, models} -> %{state | models: models}
      {:error, reason} -> %{state | status: :error, models: [], error: reason}
    end
  end

  defp schedule_refresh(state) do
    interval = Keyword.get(state.config, :refresh_interval, @default_refresh_interval)
    token = make_ref()
    timer = Process.send_after(self(), {:refresh, token}, interval)
    %{state | timer: {timer, token}}
  end

  defp cancel_refresh(%{timer: {timer, _token}} = state) do
    Process.cancel_timer(timer, async: false, info: false)
    %{state | timer: nil}
  end

  defp cancel_refresh(state), do: state

  defp public_snapshot(state) do
    Map.take(state, [:id, :status, :models, :error])
  end
end
