defmodule Miner.NodeList do
  use Agent

  alias Miner.{
    Peer
  }

  require Logger

  def start_link() do
    Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)
  end

  def get_nodes() do
    Agent.get(__MODULE__, & &1)
  end

  def add_node(node_name) when is_atom(node_name) do
    if node_name == Node.self() do
      :ignored_self_node
    else
      node_was_unknown =
        Agent.get_and_update(__MODULE__, fn nodes ->
          new_nodes = MapSet.put(nodes, node_name)
          {new_nodes != nodes, new_nodes}
        end)

      if node_was_unknown do
        Peer.broadcast_added_node(node_name)
      end
    end
  end
end
