defmodule Llamixir.Runtime.OllamaTest do
  use ExUnit.Case, async: true

  alias Llamixir.Runtime.Ollama

  defmodule HealthyHTTP do
    def get(_url, _opts) do
      body =
        ~s({"models":[{"name":"qwen2.5:0.5b","size":397000000,"modified_at":"2026-07-21T00:00:00Z","details":{"family":"qwen2"}}]})

      {:ok, 200, [], body}
    end
  end

  defmodule OfflineHTTP do
    def get(_url, _opts), do: {:error, {:failed_connect, []}}
  end

  test "reports a healthy Ollama endpoint" do
    assert Ollama.health(http_client: HealthyHTTP) == :ready
  end

  test "normalizes discovered models" do
    assert {:ok, [model]} = Ollama.models(http_client: HealthyHTTP)
    assert model.name == "qwen2.5:0.5b"
    assert model.size == 397_000_000
    assert model.metadata["family"] == "qwen2"
  end

  test "reports connection failures as unavailable" do
    assert Ollama.health(http_client: OfflineHTTP) == :unavailable
  end
end
