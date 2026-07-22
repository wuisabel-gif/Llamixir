defmodule Llamixir.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Registry, keys: :unique, name: Llamixir.Runtime.Registry},
        {Llamixir.Runtime.Supervisor, []}
      ] ++ control_children()

    opts = [strategy: :one_for_one, name: Llamixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp control_children do
    if Application.get_env(:llamixir, :control_server, false) do
      [{Llamixir.Control.Server, []}]
    else
      []
    end
  end
end
