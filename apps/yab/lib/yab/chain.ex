defmodule YAB.Chain do
  import YAB.Util, only: [empty_hash: 0]
  import YAB.Serializer, only: [pack: 1, unpack: 1]
  import YAB.Hasher, only: [hash: 1]

  alias YAB.{
    Block,
    Transaction,
    MerkleTree,
    BlockHeader,
    SignedTransaction
  }

  require SignedTransaction

  @type account_key :: binary()
  @type account_balances :: MerkleTree.t()
  @type account_changes :: %{required(account_key()) => integer()}
  @type account_error_reason :: :invalid_source_account | :low_balance

  defmacro empty_accounts, do: MerkleTree.empty()

  @spec get_account_balance(account_balances(), account_key()) :: integer()
  def get_account_balance(accounts, public_key) do
    case MerkleTree.lookup(accounts, public_key) do
      nil ->
        0

      value_binary ->
        unpack(value_binary)
    end
  end

  @type transaction_validation_error :: account_error_reason() | :invalid_transaction_signature

  @spec apply_transactions(account_balances(), [SignedTransaction.t()]) ::
          {account_balances(), [SignedTransaction.t()],
           [{SignedTransaction.t(), transaction_validation_error()}]}

  def apply_transactions(initial_accounts, transactions) do
    {accounts, invalids, valids} =
      Enum.reduce(transactions, {initial_accounts, [], []}, fn %SignedTransaction{} = transaction,
                                                               {accounts, valids, invalids} ->
        case validate_single_transaction(transaction, accounts) do
          {:ok, new_accounts} ->
            {new_accounts, [transaction | valids], invalids}

          {:error, reason} ->
            {accounts, valids, [{transaction, reason} | invalids]}
        end
      end)

    {accounts, Enum.reverse(valids), invalids}
  end

  def apply_coinbase_transaction(account_balances, %SignedTransaction{} = transaction) do
    case validate_coinbase_transaction(transaction) do
      {:ok, %{miner: miner_account, reward: reward}} ->
        add_to_account(account_balances, miner_account, reward)

      {:error, _} = error ->
        error
    end
  end

  @spec hash_transactions([SignedTransaction.t()]) :: binary()
  def hash_transactions([]) do
    empty_hash()
  end

  def hash_transactions(transactions) do
    build_transactions_tree(transactions)
    |> MerkleTree.root_hash()
  end

  defp build_transactions_tree(transactions) do
    transactions
    |> Enum.reduce(MerkleTree.empty(), fn transaction, accum_tree ->
      packed_transaction = pack(transaction)
      hash = hash(packed_transaction)

      MerkleTree.put(accum_tree, hash, packed_transaction)
    end)
  end

  @spec build_candidate(Block.t(), account_key(), account_balances(), [SignedTransaction.t()]) ::
          {:ok, Block.t()} | {:error, block_validation_error}
  def build_candidate(latest_block, miner_account, accounts, transactions) do
    candidate =
      Block.candidate(
        miner_account: miner_account,
        prev_block_hash: hash(pack(latest_block.header)),
        transactions: transactions,
        chain_root_hash: MerkleTree.root_hash(accounts)
      )

    validate_block(latest_block, accounts, candidate)
  end

  @type block_validation_error :: :invalid_prev_block_hash

  @spec validate_block(Block.t(), account_balances(), Block.t()) ::
          {:ok, Block.t(), [{SignedTransaction.t(), atom()}]} | {:error, block_validation_error}
  def validate_block(
        %Block{header: %BlockHeader{} = latest_header},
        accounts,
        %Block{
          transactions: transactions,
          header:
            %BlockHeader{
              previous_hash: previous_hash,
              chain_root_hash: chain_root_hash,
              transactions_root_hash: transactions_root_hash
            } = header
        } = block
      ) do
    latest_block_hash = hash(pack(latest_header))

    [coinbase_transaction | transactions_without_coinbase] = transactions

    {_, valid_transactions, invalid_transactions} =
      apply_transactions(accounts, transactions_without_coinbase)

    case validate_coinbase_transaction(coinbase_transaction) do
      {:ok, _} ->
        cond do
          latest_block_hash != previous_hash ->
            {:error, :invalid_prev_block_hash}

          chain_root_hash != MerkleTree.root_hash(accounts) ->
            {:error, :invalid_chain_root_hash}

          hash_transactions(transactions) != transactions_root_hash ->
            {:error, :invalid_transactions_root_hash}

          true ->
            case invalid_transactions do
              [] ->
                {:ok, block, []}

              _ ->
                new_block =
                  Block.set_transactions(block, [coinbase_transaction | valid_transactions])

                {:ok, new_block, invalid_transactions}
            end
        end

      {:error, _} = error ->
        error
    end
  end

  @spec validate_coinbase_transaction(SignedTransaction.t()) ::
          {:ok, %{miner: account_key(), reward: integer()}}
  defp validate_coinbase_transaction(%SignedTransaction{
         signature: empty_hash(),
         transaction: %{
           from_account: empty_hash(),
           to_account: miner_account,
           amount: SignedTransaction.coinbase_amount()
         }
       }) do
    {:ok, %{miner: miner_account, reward: SignedTransaction.coinbase_amount()}}
  end

  defp validate_coinbase_transaction(_) do
    {:error, :invalid_coinbase_transaction}
  end

  @spec validate_single_transaction(account_balances(), SignedTransaction.t()) ::
          {:ok, account_balances()}
          | {:error, transaction_validation_error()}
  defp validate_single_transaction(%SignedTransaction{} = signed_transaction, accounts) do
    with :ok <- validate_transaction_signature(signed_transaction),
         {:ok, new_accounts} <-
           apply_transaction_to_accounts(accounts, signed_transaction.transaction) do
      {:ok, new_accounts}
    else
      {:error, _} = error ->
        error
    end
  end

  @spec apply_transaction_to_accounts(account_balances(), Transaction.t()) ::
          {:ok, account_balances()} | {:error, account_error_reason()}
  defp apply_transaction_to_accounts(
         account_balances,
         %Transaction{
           amount: amount,
           from_account: from_account,
           to_account: to_account
         }
       ) do
    case MerkleTree.lookup(account_balances, from_account) do
      nil ->
        {:error, :invalid_source_account}

      from_balance_binary ->
        from_balance = unpack(from_balance_binary)

        if amount > from_balance do
          {:error, :low_balance}
        else
          new_balances =
            account_balances
            |> MerkleTree.put(from_account, pack(from_balance - amount))
            |> add_to_account(to_account, amount)

          {:ok, new_balances}
        end
    end
  end

  @spec add_to_account(account_balances(), account_key(), integer()) :: account_balances()
  defp add_to_account(accounts, to_account, amount)
       when is_binary(to_account) and is_integer(amount) do
    MerkleTree.update(
      accounts,
      to_account,
      pack(amount),
      &update_existing_account_value(&1, amount)
    )
  end

  defp update_existing_account_value(original_value, add_amount)
       when is_binary(original_value) and is_integer(add_amount) do
    pack(unpack(original_value) + add_amount)
  end

  @spec validate_transaction_signature(Transaction.t()) ::
          :ok | {:error, :invalid_transaction_signature}
  defp validate_transaction_signature(transaction) do
    if SignedTransaction.signature_valid?(transaction) do
      :ok
    else
      {:error, :invalid_transaction_signature}
    end
  end
end
