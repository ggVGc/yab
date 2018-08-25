defmodule Wallet.UI do
  @behaviour ChainNode.Worker.Listener

  alias YAB.{
    Transaction,
    SignedTransaction
  }

  require Logger
  require Wallet

  @impl ChainNode.Worker.Listener
  def on_chain_joined() do
    Logger.info("Joined chain")
  end

  @impl ChainNode.Worker.Listener
  def on_new_block() do
  end

  def transfer(amount, to: dest_address) when is_binary(dest_address) do
    dest_address =
      case Base.decode16(dest_address) do
        :error -> dest_address
        {:ok, address} -> address
      end

    ChainNode.Peer.broadcast_transaction(
      %Transaction{
        from_account: Wallet.public_key(),
        to_account: dest_address,
        amount: amount
      }
      |> SignedTransaction.sign(Wallet.private_key())
    )
  end
end
