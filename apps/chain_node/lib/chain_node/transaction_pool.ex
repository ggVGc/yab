defmodule ChainNode.TransactionPool do
  use Agent

  alias YAB.{
    SignedTransaction
  }

  def start_link() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def get_transactions() do
    Agent.get_and_update(__MODULE__, &{&1, []})
  end

  def add_transaction(%SignedTransaction{} = transaction) do
    Agent.update(__MODULE__, &[transaction | &1])
  end

  def remove_transactions(transactions) do
    Agent.update(
      __MODULE__,
      &Enum.reject(&1, fn %SignedTransaction{} = existing_transction ->
        existing_transction in transactions
      end)
    )
  end
end
