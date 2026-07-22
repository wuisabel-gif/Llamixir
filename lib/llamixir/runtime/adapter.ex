defmodule Llamixir.Runtime.Adapter do
  @moduledoc """
  Contract implemented by local AI runtime integrations.

  Adapters discover model and runtime state. Process supervision belongs to
  `Llamixir.Runtime.Worker`, keeping backend-specific API details isolated.
  """

  @type config :: keyword()
  @type health :: :ready | :unavailable | :error
  @type model :: %{
          required(:name) => String.t(),
          optional(:size) => non_neg_integer(),
          optional(:modified_at) => String.t(),
          optional(:metadata) => map()
        }
  @type running_model :: %{
          required(:name) => String.t(),
          optional(:size) => non_neg_integer(),
          optional(:vram_size) => non_neg_integer(),
          optional(:expires_at) => String.t(),
          optional(:metadata) => map()
        }

  @type inventory :: %{models: [model()], running_models: [running_model()]}
  @type probe_result :: {:ok, inventory()} | :unavailable | {:error, term()}

  @callback probe(config()) :: probe_result()
end
