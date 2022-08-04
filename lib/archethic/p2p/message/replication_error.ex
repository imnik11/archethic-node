defmodule Archethic.P2P.Message.ReplicationError do
  @moduledoc """
  Represents a replication error message
  """

  @enforce_keys [:address, :reason]
  defstruct [:address, :reason]

  @type reason ::
          :invalid_transaction | :transaction_already_exists

  @type t :: %__MODULE__{
          address: binary(),
          reason: reason()
        }

  @doc """
  Serialize an error reason
  """
  @spec serialize_reason(reason()) :: non_neg_integer()
  def serialize_reason(:invalid_transaction), do: 1
  def serialize_reason(:transaction_already_exists), do: 2

  @doc """
  Deserialize an error reason
  """
  @spec deserialize_reason(non_neg_integer()) :: reason()
  def deserialize_reason(1), do: :invalid_transaction
  def deserialize_reason(2), do: :transaction_already_exists
end
