defmodule LlamixirTest do
  use ExUnit.Case
  doctest Llamixir

  test "greets the world" do
    assert Llamixir.hello() == :world
  end
end
