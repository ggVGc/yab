defmodule YAB.SerializingMerkleTree do
  alias YAB.{
    MerkleTree,
    Serializer
  }

  @type t :: MerkleTree.t()
  @type key :: term()
  @type value :: term()

  @spec empty() :: __MODULE__.t()
  def empty() do
    MerkleTree.empty()
  end

  @spec lookup(__MODULE__.t(), key()) :: nil | value()
  def lookup(tree, key) do
    case MerkleTree.lookup(tree, Serializer.pack(key)) do
      nil -> nil
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

    put(tree, key, new_value)
  end

  @spec put(__MODULE__.t(), key(), value()) :: __MODULE__.t()
  def put(tree, key, value) do
    MerkleTree.put(tree, Serializer.pack(key), Serializer.pack(value))
  end

  @spec root_hash(__MODULE__.t()) :: binary()
  def root_hash(tree) do
    MerkleTree.root_hash(tree)
  end
end
