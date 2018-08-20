defmodule YAB.KeyGenerator do
  @key_entropy_bytes 16

  @spec gen_private() :: binary()
  def gen_private() do
    :crypto.strong_rand_bytes(@key_entropy_bytes)
  end

  @spec public_from_private(binary()) :: binary()
  def public_from_private(private_key) do
    :crypto.generate_key(:ecdh, :secp256k1, private_key)
  end
end
