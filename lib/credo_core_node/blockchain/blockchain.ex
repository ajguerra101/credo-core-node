defmodule CredoCoreNode.Blockchain do
  @moduledoc """
  The Blockchain context.
  """

  alias CredoCoreNode.Blockchain.{Block, Transaction}
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Network
  alias MerklePatriciaTree.Trie

  @finalization_threshold 12

  def coinbase_tx_type, do: "coinbase"
  def security_deposit_tx_type, do: "security_deposit"
  def slash_tx_type, do: "slash"
  def update_miner_ip_tx_type, do: "update_miner_ip"
  def finalization_threshold, do: @finalization_threshold

  def last_finalized_block_number, do: max(last_confirmed_block_number() - finalization_threshold(), 0)

  def last_confirmed_block_number() do
    case last_block() do
      %{number: number} ->
        number

      nil ->
        0
    end
  end

  @doc """
  Returns the list of transactions.
  """
  def list_transactions() do
    Mnesia.Repo.list(Transaction)
  end

  @doc """
  Returns the list of transactions.
  """
  def list_transactions(%Block{} = block) do
    case block_tx_trie(block) do
      nil -> []
      tx_trie -> MPT.Repo.list(tx_trie, Transaction)
    end
  end

  @doc """
  Gets a single transaction.
  """
  def get_transaction(hash) do
    Mnesia.Repo.get(Transaction, hash)
  end

  @doc """
  Creates/updates a transaction.
  """
  def write_transaction(attrs) do
    Mnesia.Repo.write(Transaction, attrs)
  end

  @doc """
  Deletes a transaction.
  """
  def delete_transaction(%Transaction{} = transaction) do
    Mnesia.Repo.delete(transaction)
  end

  @doc """
  Returns the list of blocks.
  """
  def list_blocks() do
    Mnesia.Repo.list(Block)
  end

  @doc """
  Returns the last confirmed blocks.
  """
  def last_block() do
    list_blocks()
    |> Enum.sort(&(&1.number > &2.number))
    |> List.first() || load_genesis_block()
  end

  def load_genesis_block() do
    if block = get_block_by_number(0) do
      block
    else
      genesis_block_attrs =
        [struct(CredoCoreNode.Pool.PendingTransaction, [
          data: "",
          fee: 1.1,
          hash: "BECECBB9F25FBB46092BB8946473B11779B82B5F3DAFDC9D1AD91639C23D9CE4",
          nonce: 0,
          r: "0C74EAD2F40CEA4DEF589E2C2BDBFBD00256F89201AB88688D643FB1F665BB46",
          s: "605B7B9DAFAE1D20C84BF77A7A7364BA4F3ECDBFBD07CE9D0C0BEFD92CDAD2C3",
          to: "0xa7a5df6d79203f6e6f0fa9cd550366fc9067a350",
          v: 0,
          value: 1374729257.2286
        ])]
        |> CredoCoreNode.Pool.generate_pending_block()
        |> elem(1)
        |> Map.to_list()

      struct(CredoCoreNode.Blockchain.Block, genesis_block_attrs)
      |> CredoCoreNode.Blockchain.write_block()
      |> elem(1)
    end
  end

  @doc """
  Gets a single block.
  """
  def get_block(hash) do
    Mnesia.Repo.get(Block, hash)
  end

  def get_block_by_number(number) do
    list_blocks()
    |> Enum.filter(&(&1.number == number))
    |> List.first()
  end

  def load_block_body(nil), do: nil

  def load_block_body(%Block{} = block) do
    case block_tx_trie(block) do
      nil -> block
      tx_trie ->
        body =
          tx_trie
          |> MPT.Repo.list(Transaction)
          |> ExRLP.encode()

        %{block | body: body}
    end
  end

  @doc """
  Creates/updates a block.
  """
  def write_block(%Block{hash: hash, body: body} = block)
      when not is_nil(hash) and not is_nil(body) do
    transactions =
      body
      |> ExRLP.decode()
      |> Enum.map(&Transaction.from_list(&1, type: :rlp_default))

    {:ok, tx_trie, _transactions} =
      "./leveldb/blocks/#{hash}"
      |> MerklePatriciaTree.DB.LevelDB.init()
      |> Trie.new()
      |> MPT.Repo.write_list(Transaction, transactions)

    tx_root = Base.encode16(tx_trie.root_hash)

    block
    |> Map.drop([:body])
    |> Map.put(:tx_root, tx_root)
    |> write_block()
  end

  @doc """
  Creates/updates a block.
  """
  def write_block(attrs) do
    Mnesia.Repo.write(Block, attrs)
  end

  @doc """
  Marks a block as invalid.
  """
  def mark_block_as_invalid(pending_block) do
    Pool.delete_pending_block(pending_block)
  end

  @doc """
  Deletes a block.
  """
  def delete_block(%Block{} = block) do
    Mnesia.Repo.delete(block)
  end

  def propagate_block(block) do
    Network.propagate_record(block)

    {:ok, block}
  end

  defp block_tx_trie(%Block{tx_root: nil}), do: nil
  defp block_tx_trie(%Block{hash: nil}), do: nil

  defp block_tx_trie(%Block{tx_root: tx_root, hash: hash}) do
    db = MerklePatriciaTree.DB.LevelDB.init("./leveldb/blocks/#{hash}")
    if db |> elem(1) |> Exleveldb.is_empty?() do
      nil
    else
      Trie.new(db, elem(Base.decode16(tx_root), 1))
    end
  end
end
