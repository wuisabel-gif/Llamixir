defmodule Llamixir.Control.ServerTest do
  use ExUnit.Case, async: false

  alias Llamixir.Control.{Client, Server}

  setup do
    path =
      Path.join(
        System.tmp_dir!(),
        "llamixir-control-#{System.unique_integer([:positive])}.sock"
      )

    name = String.to_atom("control_server_#{System.unique_integer([:positive])}")
    start_supervised!({Server, path: path, name: name})
    on_exit(fn -> File.rm(path) end)
    %{path: path}
  end

  test "negotiates the versioned control protocol", %{path: path} do
    assert {:ok, %{"ok" => true, "protocol" => 1}} = Client.ping(path: path)
  end

  test "returns normalized runtime snapshots", %{path: path} do
    assert {:ok, snapshots} = Client.snapshots(path: path)
    assert is_list(snapshots)
  end

  test "returns structured errors for unknown commands", %{path: path} do
    assert {:ok, %{"ok" => false, "error" => "unknown_command"}} =
             Client.request("does-not-exist", path: path)
  end
end
