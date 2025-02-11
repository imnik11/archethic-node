defmodule Archethic.P2P.Client.ConnectionTest do
  use ArchethicCase

  alias Archethic.Crypto

  alias Archethic.P2P.Client.Connection, as: ARCHEthicConnection
  alias Archethic.P2P.Message.Balance
  alias Archethic.P2P.Message.GetBalance
  alias Archethic.P2P.MessageEnvelop

  test "start_link/1 should open a socket and a connection worker and initialize the backlog and lookup tables" do
    {:ok, pid} =
      ARCHEthicConnection.start_link(
        transport: __MODULE__.MockTransport,
        ip: {127, 0, 0, 1},
        port: 3000,
        node_public_key: "key1"
      )

    assert %Connection{mod_state: %{socket: _, request_id: 0, messages: %{}}} =
             :sys.get_state(pid)
  end

  describe "send_message/3" do
    test "should send the message and enqueue the request" do
      {:ok, pid} =
        ARCHEthicConnection.start_link(
          transport: __MODULE__.MockTransport,
          ip: {127, 0, 0, 1},
          port: 3000,
          node_public_key: Crypto.first_node_public_key()
        )

      spawn(fn ->
        ARCHEthicConnection.send_message(Crypto.first_node_public_key(), %GetBalance{
          address: <<0::8, :crypto.strong_rand_bytes(32)::binary>>
        })
      end)

      Process.sleep(50)

      assert %Connection{
               mod_state: %{
                 messages: %{0 => _},
                 request_id: 1
               }
             } = :sys.get_state(pid)
    end

    test "should get an error when the timeout is reached" do
      {:ok, pid} =
        ARCHEthicConnection.start_link(
          transport: __MODULE__.MockTransport,
          ip: {127, 0, 0, 1},
          port: 3000,
          node_public_key: Crypto.first_node_public_key()
        )

      assert {:error, :timeout} =
               ARCHEthicConnection.send_message(
                 Crypto.first_node_public_key(),
                 %GetBalance{address: <<0::8, :crypto.strong_rand_bytes(32)::binary>>},
                 10
               )

      assert %Connection{mod_state: %{messages: %{}}} = :sys.get_state(pid)
    end

    test "should receive the response after sending the request" do
      {:ok, pid} =
        ARCHEthicConnection.start_link(
          transport: __MODULE__.MockTransport,
          ip: {127, 0, 0, 1},
          port: 3000,
          node_public_key: Crypto.first_node_public_key()
        )

      me = self()

      spawn(fn ->
        {:ok, %Balance{}} =
          ARCHEthicConnection.send_message(
            Crypto.first_node_public_key(),
            %GetBalance{address: <<0::8, :crypto.strong_rand_bytes(32)::binary>>}
          )

        send(me, :done)
      end)

      Process.sleep(10)

      msg_envelop =
        %MessageEnvelop{
          message: %Balance{},
          message_id: 0,
          sender_public_key: Crypto.first_node_public_key()
        }
        |> MessageEnvelop.encode(Crypto.first_node_public_key())

      send(pid, {__MODULE__.MockTransport, make_ref(), msg_envelop})

      assert_receive :done, 1_000

      assert %Connection{
               mod_state: %{
                 messages: %{}
               }
             } = :sys.get_state(pid)
    end
  end

  defmodule MockTransport do
    alias Archethic.P2P.Client.Transport

    @behaviour Transport

    def handle_connect(_ip, _port) do
      {:ok, make_ref()}
    end

    def handle_send(_socket, _data), do: :ok

    def handle_message({_, _, data}), do: {:ok, data}
  end
end
