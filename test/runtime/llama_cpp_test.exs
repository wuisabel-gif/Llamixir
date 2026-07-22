defmodule Llamixir.Runtime.LlamaCppTest do
  use ExUnit.Case, async: true

  alias Llamixir.Runtime.LlamaCpp

  defmodule HealthyHTTP do
    def get(url, _opts) do
      if String.ends_with?(url, "/health") do
        {:ok, 200, [], ~s({"status":"ok"})}
      else
        body =
          ~s({"object":"list","data":[{"id":"qwen.gguf","object":"model","created":1784592000,"owned_by":"llamacpp","meta":{"size":4700000000,"n_params":7600000000}}]})

        {:ok, 200, [], body}
      end
    end
  end

  defmodule OfflineHTTP do
    def get(_url, _opts), do: {:error, :econnrefused}
  end

  test "reports server health" do
    assert LlamaCpp.health(http_client: HealthyHTTP) == :ready
    assert LlamaCpp.health(http_client: OfflineHTTP) == :unavailable
  end

  test "normalizes the loaded llama.cpp model" do
    assert {:ok, [model]} = LlamaCpp.models(http_client: HealthyHTTP)
    assert model.name == "qwen.gguf"
    assert model.size == 4_700_000_000
    assert model.metadata["owned_by"] == "llamacpp"
  end

  test "exposes the loaded model as running" do
    assert {:ok, [%{name: "qwen.gguf"}]} = LlamaCpp.running_models(http_client: HealthyHTTP)
  end
end
