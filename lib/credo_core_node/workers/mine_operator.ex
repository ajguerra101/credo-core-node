defmodule CredoCoreNode.Workers.MineOperator do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Blockchain.BlockProposer
  alias CredoCoreNode.Mining

  @block_proposal_timeout 10000

  def start_link(interval \\ 300_000) do
    GenServer.start_link(__MODULE__, interval, name: __MODULE__)
  end

  def init(interval) do
    Logger.info("Initializing the mine operator...")

    handle_info(:mine_block, interval)

    {:ok, interval}
  end

  def handle_info(:mine_block, interval) do
    case Mining.is_miner?() do
      true ->
        Blockchain.last_block()
        |> BlockProposer.maybe_propose_next_block()

      false ->
        schedule_mine_block(interval)
    end

    {:noreply, interval}
  end

  defp schedule_mine_block(interval) do
    send_after(self(), :mine_block, interval)
  end
end