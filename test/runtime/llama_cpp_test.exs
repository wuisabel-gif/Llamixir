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

  test "probes health and normalizes the loaded llama.cpp model" do
    assert {:ok, %{models: [model], running_models: [running]}} =
             LlamaCpp.probe(http_client: HealthyHTTP)

    assert model.name == "qwen.gguf"
    assert model.size == 4_700_000_000
    assert model.metadata["owned_by"] == "llamacpp"
    assert running.name == "qwen.gguf"
  end

  test "reports connection failures as unavailable" do
    assert LlamaCpp.probe(http_client: OfflineHTTP) == :unavailable
  end
end
