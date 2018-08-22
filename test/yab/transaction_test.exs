defmodule YAB.TransactionTest do
  use YAB.TestCase

  alias YAB.{
    Transaction,
    Serializer,
    Signer
  }

  test "Verifies signed transaction" do
    from_keys = new_keys()

    transaction = %Transaction{
      from_account: from_keys.public,
      to_account: new_keys().public,
      amount: 1
    }

    signed_transaction = Transaction.sign(transaction, from_keys.private)

    assert Signer.verify(
             Serializer.pack(transaction),
             signed_transaction.signature,
             from_keys.public
           )
  end
end
