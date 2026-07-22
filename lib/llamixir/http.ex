defmodule Llamixir.HTTP do
  @moduledoc false

  @spec get(String.t(), keyword()) ::
          {:ok, non_neg_integer(), [{String.t(), String.t()}], binary()} | {:error, term()}
  def get(url, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 2_000)
    request = {String.to_charlist(url), []}
    http_options = [timeout: timeout, connect_timeout: timeout]

    case :httpc.request(:get, request, http_options, body_format: :binary) do
      {:ok, {{_version, status, _reason}, headers, body}} ->
        normalized_headers =
          Enum.map(headers, fn {name, value} -> {to_string(name), to_string(value)} end)

        {:ok, status, normalized_headers, body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
