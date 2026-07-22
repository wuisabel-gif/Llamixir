defmodule Llamixir.HTTPTest do
  use ExUnit.Case, async: true

  test "rejects HTTPS until peer verification is supported" do
    assert Llamixir.HTTP.get("https://127.0.0.1:11434") ==
             {:error, :https_not_supported}
  end

  test "rejects malformed runtime URLs" do
    assert Llamixir.HTTP.get("not-a-url") == {:error, :invalid_url}
  end
end
