defmodule YAB.Serializer do
  def pack(term) do
    :erlang.term_to_binary(term)
  end

  def unpack(data) when is_binary(data) do
    :erlang.binary_to_term(data)
  end
end
