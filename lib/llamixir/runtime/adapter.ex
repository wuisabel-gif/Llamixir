defmodule Llamixir.Runtime.Adapter do
  @moduledoc """
  Contract implemented by local AI runtime integrations.

  Adapters discover model and runtime state. Process supervision belongs to
  `Llamixir.Runtime.Worker`, keeping backend-specific API details isolated.
  """

  @type config :: keyword()
  @type health :: :ready | :unavailable | {:error, term()}
  @type model :: %{
          required(:name) => String.t(),
          optional(:size) => non_neg_integer(),
          optional(:modified_at) => String.t(),
          optional(:metadata) => map()
        }

  @callback health(config()) :: health()
  @callback models(config()) :: {:ok, [model()]} | {:error, term()}
end
