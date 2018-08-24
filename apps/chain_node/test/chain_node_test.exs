defmodule ChainNodeTest do
  use ExUnit.Case
  doctest ChainNode

  test "greets the world" do
    assert ChainNode.hello() == :world
  end
end
