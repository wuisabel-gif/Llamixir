defmodule Llamixir.Runtime.OllamaTest do
  use ExUnit.Case, async: true

  alias Llamixir.Runtime.Ollama

  defmodule HealthyHTTP do
    def get(url, _opts) do
      body = if String.ends_with?(url, "/api/ps"), do: running_body(), else: models_body()
      {:ok, 200, [], body}
    end

    defp models_body do
      body =
        ~s({"models":[{"name":"qwen2.5:0.5b","size":397000000,"modified_at":"2026-07-21T00:00:00Z","details":{"family":"qwen2"}}]})

      body
    end

    defp running_body do
      ~s({"models":[{"name":"qwen2.5:0.5b","size":397000000,"size_vram":250000000,"expires_at":"2026-07-21T01:00:00Z","details":{"family":"qwen2"}}]})
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

  test "normalizes loaded models and VRAM usage" do
    assert {:ok, [model]} = Ollama.running_models(http_client: HealthyHTTP)
    assert model.name == "qwen2.5:0.5b"
    assert model.vram_size == 250_000_000
    assert model.expires_at == "2026-07-21T01:00:00Z"
  end
end
