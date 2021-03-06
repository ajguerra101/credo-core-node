defmodule CredoCoreNode.Workers.DepositRecognizer do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Mining.Deposit
  alias CredoCoreNode.Adapters.BlockchainAdapter
  alias CredoCoreNode.Adapters.DepositAdapter

  @default_interval 120_000
  @blockchain Application.get_env(:credo_core_node, BlockchainAdapter, Blockchain)
  @deposit Application.get_env(:credo_core_node, DepositAdapter, Deposit)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    Logger.info("Initializing the deposit recognizer...")

    # TODO: Implement a more robust way of initially setting the last processed block.
    state = %{
      interval: Keyword.get(opts, :interval, @default_interval),
      last_processed_block: @blockchain.last_block()
    }

    schedule_recognize_deposits(state.interval)

    {:ok, state}
  end

  def handle_info(
        :recognize_deposits,
        %{last_processed_block: last_processed_block, interval: interval} = state
      ) do
    schedule_recognize_deposits(interval)

    last_processed_block_number =
      if last_processed_block, do: last_processed_block.number, else: 0

    processable_blocks = @blockchain.list_processable_blocks(last_processed_block_number)

    processable_blocks
    |> Enum.each(fn block -> @deposit.maybe_recognize_deposits(block) end)

    last_processed_block = @blockchain.last_processed_block(processable_blocks)

    state = %{state | last_processed_block: last_processed_block}

    {:noreply, state}
  end

  def handle_call(:ping, _, state) do
    {:reply, :pong, state}
  end

  defp schedule_recognize_deposits(interval) do
    send_after(self(), :recognize_deposits, interval)
  end
end
