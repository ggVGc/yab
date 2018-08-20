defmodule YAB.MerkleTree do
  alias YAB.{
    Serializer
  }

  @type t :: :gb_merkle_trees.tree()
  @type key :: term()
  @type value :: term()

  @spec empty() :: __MODULE__.t()
  def empty() do
    :gb_merkle_trees.empty()
  end

  @spec lookup(__MODULE__.t(), key()) :: nil | value()
  def lookup(tree, key) do
    case :gb_merkle_trees.lookup(Serializer.pack(key), tree) do
      :none -> nil
      result -> Serializer.unpack(result)
    end
  end

  @spec update(__MODULE__.t(), key(), value(), (value() -> value())) :: __MODULE__.t()
  def update(tree, key, initial, fun) do
    new_value =
      case lookup(tree, key) do
        nil ->
          initial

        value ->
          fun.(value)
      end

    :gb_merkle_trees.enter(Serializer.pack(key), Serializer.pack(new_value), tree)
  end

  @spec put(__MODULE__.t(), key(), value()) :: __MODULE__.t()
  def put(tree, key, value) do
    update(tree, key, value, & &1)
  end

  @spec root_hash(__MODULE__.t()) :: binary()
  def root_hash(tree) do
    :gb_merkle_trees.root_hash(tree)
  end
end
