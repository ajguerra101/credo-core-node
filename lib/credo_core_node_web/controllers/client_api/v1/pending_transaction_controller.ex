defmodule CredoCoreNodeWeb.ClientApi.V1.PendingTransactionController do
  use CredoCoreNodeWeb, :controller

  alias CredoCoreNode.Pool

  def create(conn, params) do
    {:ok, private_key} =
      conn
      |> get_req_header("x-ccn-private-key")
      |> hd()
      |> Base.decode64()

    # TODO: params store keys as strings and building structure expects passing them as atoms;
    #   converting keys from string to atom is a common task, probably should be somehow generalized
    attrs = Enum.map(params, fn {key, value} -> {:"#{key}", value} end)

    {:ok, tx} = Pool.generate_pending_transaction(private_key, attrs)

    if Pool.is_tx_invalid?(tx) do
      Pool.propagate_pending_transaction(tx)

      conn
      |> put_status(:created)
      |> render("show.json", pending_transaction: tx)
    else
      send_resp(conn, :unprocessable_entity, "")
    end
  end
end
