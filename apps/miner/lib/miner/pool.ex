defmodule Miner.Pool do
  use Agent

  def start_link() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def get_transactions() do
    Agent.get(__MODULE__, & &1)
  end
end
