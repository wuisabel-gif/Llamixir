defmodule Llamixir.Runtime.Ollama do
  @moduledoc "Runtime adapter for the Ollama HTTP API."

  @behaviour Llamixir.Runtime.Adapter

  @default_url "http://127.0.0.1:11434"

  @impl true
  def health(config) do
    case request_tags(config) do
      {:ok, _body} -> :ready
      {:error, {:http_status, status}} -> {:error, {:http_status, status}}
      {:error, reason} when reason in [:econnrefused, :timeout] -> :unavailable
      {:error, {:failed_connect, _details}} -> :unavailable
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def models(config) do
    with {:ok, body} <- request_tags(config),
         {:ok, %{"models" => models}} when is_list(models) <- JSON.decode(body) do
      {:ok, Enum.map(models, &normalize_model/1)}
    else
      {:ok, _unexpected} -> {:error, :invalid_response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request_tags(config) do
    http = Keyword.get(config, :http_client, Llamixir.HTTP)
    timeout = Keyword.get(config, :timeout, 2_000)
    url = Keyword.get(config, :url, System.get_env("LLAMIXIR_OLLAMA_URL", @default_url))

    case http.get("#{String.trim_trailing(url, "/")}/api/tags", timeout: timeout) do
      {:ok, 200, _headers, body} -> {:ok, body}
      {:ok, status, _headers, _body} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_model(model) do
    %{
      name: Map.get(model, "name", "unknown"),
      size: Map.get(model, "size", 0),
      modified_at: Map.get(model, "modified_at"),
      metadata: Map.get(model, "details", %{})
    }
  end
end
