defmodule YAB.Signer do
  @private_key Application.get_env(:yab, __MODULE__)[:private_key]
  @public_key :crypto.generate_key(:ecdh, :secp256k1, @private_key)

  @spec sign(binary()) :: binary()
  def sign(data) do
    :crypto.sign(:ecdsa, :sha256, data, [@private_key, :secp256k1])
  end

  @spec verify(binary(), binary()) :: boolean()
  defp verify(data, signature) do
    :crypto.verify(:ecdsa, :sha256, data, signature, [@public_key, :secp256k1])
  end
end
