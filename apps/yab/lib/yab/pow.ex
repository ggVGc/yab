defmodule YAB.POW do
  alias YAB.{
    BlockHeader,
    Block,
    Hasher,
    Serializer
  }

  require Block

  @target_difficulty_value :binary.list_to_bin(
                             for(_ <- 1..Block.difficulty(), do: 0) ++
                               for(_ <- 1..(32 - Block.difficulty()), do: 255)
                           )

  @spec work(BlockHeader.t()) :: BlockHeader.t()
  def work(%BlockHeader{nonce: nonce} = header) do
    hash = Hasher.hash(Serializer.pack(header))

    if hash <= @target_difficulty_value do
      header
    else
      work(%{header | nonce: nonce + 1})
    end
  end
end
