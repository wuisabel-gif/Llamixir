defmodule Llamixir.Runtime.Ollama do
  @moduledoc "Runtime adapter for the Ollama HTTP API."

  @behaviour Llamixir.Runtime.Adapter

  @default_url "http://127.0.0.1:11434"

  @impl true
  def probe(config) do
    with {:ok, models_body} <- request(config, "/api/tags"),
         {:ok, models} <- decode_models(models_body, &normalize_model/1),
         {:ok, running_body} <- request(config, "/api/ps"),
         {:ok, running_models} <- decode_models(running_body, &normalize_running_model/1) do
      {:ok, %{models: models, running_models: running_models}}
    else
      {:error, reason} -> classify_error(reason)
    end
  end

  defp decode_models(body, normalize) do
    with {:ok, %{"models" => models}} when is_list(models) <- JSON.decode(body) do
      {:ok, Enum.map(models, normalize)}
    else
      {:ok, _unexpected} -> {:error, :invalid_response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request(config, path) do
    http = Keyword.get(config, :http_client, Llamixir.HTTP)
    timeout = Keyword.get(config, :timeout, 2_000)
    url = Keyword.get(config, :url, System.get_env("LLAMIXIR_OLLAMA_URL", @default_url))

    case http.get("#{String.trim_trailing(url, "/")}#{path}", timeout: timeout) do
      {:ok, 200, _headers, body} -> {:ok, body}
      {:ok, status, _headers, _body} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp classify_error(reason) when reason in [:econnrefused, :timeout], do: :unavailable
  defp classify_error({:failed_connect, _details}), do: :unavailable
  defp classify_error(reason), do: {:error, reason}

  defp normalize_model(model) do
    %{
      name: Map.get(model, "name", "unknown"),
      size: Map.get(model, "size", 0),
      modified_at: Map.get(model, "modified_at"),
      metadata: Map.get(model, "details", %{})
    }
  end

  defp normalize_running_model(model) do
    %{
      name: Map.get(model, "name", "unknown"),
      size: Map.get(model, "size", 0),
      vram_size: Map.get(model, "size_vram", 0),
      expires_at: Map.get(model, "expires_at"),
      metadata: Map.get(model, "details", %{})
    }
  end
end
