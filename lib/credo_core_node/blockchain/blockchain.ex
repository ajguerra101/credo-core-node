defmodule CredoCoreNode.Blockchain do
  @moduledoc """
  The Blockchain context.
  """

  alias CredoCoreNode.Blockchain.Transaction
  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Pool
  alias Mnesia.Repo

  def coinbase_tx_type, do: "coinbase"
  def security_deposit_tx_type, do: "security_deposit"
  def slash_tx_type, do: "slash"
  def update_validator_ip_tx_type, do: "update_validator_ip"

  @doc """
  Returns the list of transactions.
  """
  def list_transactions() do
    Repo.list(Transaction)
  end

  @doc """
  Gets a single transaction.
  """
  def get_transaction(hash) do
    Repo.get(Transaction, hash)
  end

  @doc """
  Creates/updates a transaction.
  """
  def write_transaction(attrs) do
    Repo.write(Transaction, attrs)
  end

  @doc """
  Deletes a transaction.
  """
  def delete_transaction(%Transaction{} = transaction) do
    Repo.delete(transaction)
  end

  @doc """
  Returns the list of blocks.
  """
  def list_blocks() do
    Repo.list(Block)
  end

  @doc """
  Gets a single block.
  """
  def get_block(hash) do
    Repo.get(Block, hash)
  end

  @doc """
  Gets a single block by the number.
  """
  def get_block_by_number(number) do
    list_blocks()
    |> Enum.filter(&(&1.number == number))
    |> List.first()
  end

  @doc """
  Creates/updates a block.
  """
  def write_block(attrs) do
    Repo.write(Block, attrs)
  end

  @doc """
  Marks a block as invalid.

  TODO: Add some kind of status field for marking blocks as invalid.
  TODO: Clean up invalid pending blocks after finalization threshold is passed.
  """
  def mark_block_as_invalid(pending_block) do
    Pool.delete_pending_block(pending_block)
  end

  @doc """
  Deletes a block.
  """
  def delete_block(%Block{} = block) do
    Repo.delete(block)
  end
end
