defmodule ChainNode.TransactionPool do
  use Agent

  alias YAB.{
    SignedTransaction
  }

  def start_link() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def get_transactions() do
    Agent.get(__MODULE__, & &1)
  end

  def add_transaction(%SignedTransaction{} = transaction) do
    Agent.update(__MODULE__, &[transaction | &1])
  end
end
