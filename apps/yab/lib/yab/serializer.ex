defmodule YAB.Serializer do
  @spec pack(term()) :: binary()
  def pack(term) do
    :erlang.term_to_binary(term)
  end

  @spec unpack(binary()) :: term()
  def unpack(data) when is_binary(data) do
    :erlang.binary_to_term(data)
  end
end
