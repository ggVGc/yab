defmodule YAB.Signer do
  @spec sign(binary(), binary()) :: binary()
  def sign(data, private_key) do
    :crypto.sign(:ecdsa, :sha256, data, [private_key, :secp256k1])
  end

  @spec verify(binary(), binary(), binary()) :: boolean()
  def verify(data, signature, public_key) do
    :crypto.verify(:ecdsa, :sha256, data, signature, [public_key, :secp256k1])
  end
end
