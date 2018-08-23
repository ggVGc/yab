defmodule YAB.MerkleTree do
  @type t :: :gb_merkle_trees.tree()
  @type key :: binary()
  @type value :: binary()

  @spec empty() :: __MODULE__.t()
  def empty() do
    :gb_merkle_trees.empty()
  end

  @spec lookup(__MODULE__.t(), key()) :: nil | value()
  def lookup(tree, key) do
    case :gb_merkle_trees.lookup(key, tree) do
      :none -> nil
      result -> result
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

    put(tree, key, new_value)
  end

  @spec put(__MODULE__.t(), key(), value()) :: __MODULE__.t()
  def put(tree, key, value) do
    :gb_merkle_trees.enter(key, value, tree)
  end

  @spec root_hash(__MODULE__.t()) :: binary()
  def root_hash(tree) do
    :gb_merkle_trees.root_hash(tree)
  end
end
