defmodule ChainNode.UI do
  alias YAB.{
    Chain
  }

  def list_accounts() do
    ChainNode.Worker.get_account_balances()
    |> Enum.map(fn {account, value} ->
      %{
        Base.encode16(account) => value
      }
    end)
  end

  def set_account(account_hex) when is_binary(account_hex) do
    ChainNode.Worker.set_account(Base.decode16!(account_hex))
  end

  def status() do
    %{accounts: accounts, public_key: public_key} = ChainNode.Worker.get_state()

    [
      balance: Chain.get_account_balance(accounts, public_key),
      account: Base.encode16(ChainNode.Worker.get_state().public_key)
    ]
  end
end
