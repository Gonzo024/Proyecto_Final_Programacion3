defmodule AzarTest do
  use ExUnit.Case
  doctest Azar

  test "greets the world" do
    assert Azar.hello() == :world
  end
end
