defmodule YAB.POW do
  alias YAB.{
    BlockHeader,
    Block,
    Hasher,
    Serializer
  }

  require Block

  @spec work(BlockHeader.t()) :: BlockHeader.t()
  def work(%BlockHeader{nonce: nonce} = header) do
    hash = Hasher.hash(Serializer.pack(header))

    if matches_difficulty_target?(hash) do
      header
    else
      work(%{header | nonce: nonce + 1})
    end
  end

  @target_leading_zeroes <<0::size(Block.difficulty())-unit(8)>>

  @spec matches_difficulty_target?(binary()) :: boolean()
  defp matches_difficulty_target?(hash) do
    <<leading_zeroes::binary-size(Block.difficulty()), _::binary>> = hash
    leading_zeroes == @target_leading_zeroes
  end
end
