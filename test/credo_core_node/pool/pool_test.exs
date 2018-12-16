defmodule CredoCoreNode.PoolTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.{Blockchain, Pool}

  alias Decimal, as: D

  describe "pending_blocks" do
    @describetag table_name: :pending_blocks
    @private_key :crypto.strong_rand_bytes(32)
    @attrs [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1), data: ""]

    def pending_block_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Pool.write_pending_transaction()

      {:ok, pending_block} =
        [pending_transaction]
        |> Pool.generate_pending_block()
        |> elem(1)
        |> Pool.write_pending_block()

      pending_block
    end

    test "list_pending_blocks/0 returns all pending_blocks" do
      pending_block = pending_block_fixture()
      assert Enum.member?(Pool.list_pending_blocks(), pending_block)
    end

    test "get_pending_block!/1 returns the pending_block with given hash" do
      pending_block = pending_block_fixture()
      assert Pool.get_pending_block(pending_block.hash) == pending_block
    end

    test "writes_pending_block/1 with valid data creates a pending_block" do
      Blockchain.load_genesis_block()

      pending_block = pending_block_fixture()

      assert pending_block.number == 1
    end

    test "delete_pending_block/1 deletes the pending_block" do
      pending_block = pending_block_fixture()
      assert {:ok, pending_block} = Pool.delete_pending_block(pending_block)
      assert Pool.get_pending_block(pending_block.hash) == nil
    end
  end

  describe "pending_transactions" do
    @describetag table_name: :pending_transactions
    @private_key :crypto.strong_rand_bytes(32)
    @attrs [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1), data: ""]

    def pending_transaction_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Pool.write_pending_transaction()

      pending_transaction
    end

    test "list_pending_transactions/0 returns all pending_transactions" do
      pending_transaction = pending_transaction_fixture()
      assert Enum.member?(Pool.list_pending_transactions(), pending_transaction)
    end

    test "get_pending_transaction!/1 returns the pending_transaction with given hash" do
      pending_transaction = pending_transaction_fixture()
      assert Pool.get_pending_transaction(pending_transaction.hash) == pending_transaction
    end

    test "write_pending_transaction/1 with valid data creates a pending_transaction" do
      assert {:ok, pending_transaction} =
               @private_key
               |> Pool.generate_pending_transaction(@attrs)
               |> elem(1)
               |> Pool.write_pending_transaction()

      assert pending_transaction.nonce == @attrs[:nonce]
      assert pending_transaction.to == @attrs[:to]
      assert pending_transaction.value == @attrs[:value]
      assert pending_transaction.fee == @attrs[:fee]
      assert pending_transaction.data == @attrs[:data]
    end

    test "delete_pending_transaction/1 deletes the pending_transaction" do
      pending_transaction = pending_transaction_fixture()
      assert {:ok, pending_transaction} = Pool.delete_pending_transaction(pending_transaction)
      assert Pool.get_pending_transaction(pending_transaction.hash) == nil
    end
  end
end
