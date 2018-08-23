defmodule Miner.Peer do
  alias Miner.{
    NodeList,
    Worker
  }

  alias YAB.{
    Block
  }

  require Logger

  def get_blocks() do
    node_name = Enum.random(NodeList.get_nodes())
    :rpc.call(node_name, Worker, :get_blocks, [])
  end

  def announce_self(target_node) do
    Logger.debug("(#{Node.self()}) Announcing self to: #{target_node}")
    NodeList.add_node(target_node)
    :rpc.call(target_node, NodeList, :add_node, [Node.self()])
  end

  def broadcast_new_block(%Block{} = block) do
    Logger.debug("(#{Node.self()}) Broadcasting new block")
    broadcast(Worker, :add_external_block, [block])
  end

  def broadcast_added_node(new_node_name) do
    Logger.debug("(#{Node.self()}) Broadcasting new node name: #{new_node_name}")

    broadcast(NodeList, :add_node, [new_node_name])
    :rpc.call(new_node_name, NodeList, :add_node, [Node.self()])
  end

  defp broadcast(module, function, args) do
    Enum.each(NodeList.get_nodes(), fn target_node ->
      if target_node != Node.self() do
        :rpc.call(target_node, module, function, args)
      end
    end)
  end
end
