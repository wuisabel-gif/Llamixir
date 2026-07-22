defmodule Llamixir.Runtime.LlamaCpp do
  @moduledoc "Runtime adapter for the llama.cpp HTTP server."

  @behaviour Llamixir.Runtime.Adapter

  @default_url "http://127.0.0.1:8080"

  @impl true
  def health(config) do
    case request(config, "/health") do
      {:ok, _body} -> :ready
      {:error, {:http_status, status}} -> {:error, {:http_status, status}}
      {:error, reason} when reason in [:econnrefused, :timeout] -> :unavailable
      {:error, {:failed_connect, _details}} -> :unavailable
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def models(config) do
    with {:ok, body} <- request(config, "/v1/models"),
         {:ok, %{"data" => models}} when is_list(models) <- JSON.decode(body) do
      {:ok, Enum.map(models, &normalize_model/1)}
    else
      {:ok, _unexpected} -> {:error, :invalid_response}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def running_models(config) do
    with {:ok, models} <- models(config) do
      {:ok,
       Enum.map(models, fn model ->
         %{
           name: model.name,
           size: model.size,
           vram_size: 0,
           expires_at: nil,
           metadata: model.metadata
         }
       end)}
    end
  end

  defp request(config, path) do
    http = Keyword.get(config, :http_client, Llamixir.HTTP)
    timeout = Keyword.get(config, :timeout, 2_000)
    url = Keyword.get(config, :url, System.get_env("LLAMIXIR_LLAMA_CPP_URL", @default_url))

    case http.get("#{String.trim_trailing(url, "/")}#{path}", timeout: timeout) do
      {:ok, 200, _headers, body} -> {:ok, body}
      {:ok, status, _headers, _body} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_model(model) do
    metadata = Map.get(model, "meta") || %{}

    %{
      name: Map.get(model, "id", "unknown"),
      size: Map.get(metadata, "size", 0),
      modified_at: normalize_created(Map.get(model, "created")),
      metadata: Map.put(metadata, "owned_by", Map.get(model, "owned_by"))
    }
  end

  defp normalize_created(created) when is_integer(created) do
    created |> DateTime.from_unix!() |> DateTime.to_iso8601()
  end

  defp normalize_created(_created), do: nil
end
