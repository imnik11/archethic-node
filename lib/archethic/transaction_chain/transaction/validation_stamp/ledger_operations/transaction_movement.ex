defmodule Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations.TransactionMovement do
  @moduledoc """
  Represents the ledger movements of the transaction extracted from
  the ledger or recipients part of the transaction and validated with the unspent outputs
  """
  defstruct [:to, :amount, :type]

  alias __MODULE__.Type
  alias Archethic.Crypto
  alias Archethic.Utils

  @typedoc """
  TransactionMovement is composed from:
  - to: receiver address of the movement
  - amount: specify the number assets to transfer to the recipients (smallest unit of uco 10^-8)
  - type: asset type (ie. UCO or NFT)
  """
  @type t() :: %__MODULE__{
          to: Crypto.versioned_hash(),
          amount: non_neg_integer(),
          type: Type.t()
        }

  @doc """
  Serialize a transaction movement into binary format

  ## Examples

      iex> %TransactionMovement{
      ...>    to: <<0, 214, 107, 17, 107, 227, 11, 17, 43, 204, 48, 78, 129, 145, 126, 45, 68, 194,
      ...>      159, 19, 92, 240, 29, 37, 105, 183, 232, 56, 42, 163, 236, 251, 186>>,
      ...>    amount: 30_000_000,
      ...>    type: :UCO
      ...>  }
      ...>  |> TransactionMovement.serialize()
      <<
      # Node public key
      0, 214, 107, 17, 107, 227, 11, 17, 43, 204, 48, 78, 129, 145, 126, 45, 68, 194,
      159, 19, 92, 240, 29, 37, 105, 183, 232, 56, 42, 163, 236, 251, 186,
      # Amount
      0, 0, 0, 0, 1, 201, 195, 128,
      # UCO type
      0
      >>

      iex> %TransactionMovement{
      ...>    to: <<0, 214, 107, 17, 107, 227, 11, 17, 43, 204, 48, 78, 129, 145, 126, 45, 68, 194,
      ...>      159, 19, 92, 240, 29, 37, 105, 183, 232, 56, 42, 163, 236, 251, 186>>,
      ...>    amount: 30_000_000,
      ...>    type: {:NFT, <<0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140, 74,
      ...>      197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175>>}
      ...>  }
      ...>  |> TransactionMovement.serialize()
      <<
      # Node public key
      0, 214, 107, 17, 107, 227, 11, 17, 43, 204, 48, 78, 129, 145, 126, 45, 68, 194,
      159, 19, 92, 240, 29, 37, 105, 183, 232, 56, 42, 163, 236, 251, 186,
      # Amount
      0, 0, 0, 0, 1, 201, 195, 128,
      # NFT type
      1,
      # NFT address
      0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140, 74,
      197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175
      >>
  """
  @spec serialize(t()) :: <<_::64, _::_*8>>
  def serialize(%__MODULE__{to: to, amount: amount, type: type}) do
    <<to::binary, amount::64, Type.serialize(type)::binary>>
  end

  @doc """
  Deserialize an encoded transaction movement

  ## Examples

      iex> <<0, 0, 214, 107, 17, 107, 227, 11, 17, 43, 204, 48, 78, 129, 145, 126, 45, 68, 194,
      ...> 159, 19, 92, 240, 29, 37, 105, 183, 232, 56, 42, 163, 236, 251, 186,
      ...> 0, 0, 0, 0, 1, 201, 195, 128, 0
      ...> >>
      ...> |> TransactionMovement.deserialize()
      {
        %TransactionMovement{
          to: <<0, 0, 214, 107, 17, 107, 227, 11, 17, 43, 204, 48, 78, 129, 145, 126, 45, 68, 194,
            159, 19, 92, 240, 29, 37, 105, 183, 232, 56, 42, 163, 236, 251, 186>>,
          amount: 30_000_000,
          type: :UCO
        },
        ""
      }

      iex> <<0, 0, 214, 107, 17, 107, 227, 11, 17, 43, 204, 48, 78, 129, 145, 126, 45, 68, 194,
      ...> 159, 19, 92, 240, 29, 37, 105, 183, 232, 56, 42, 163, 236, 251, 186,
      ...> 0, 0, 0, 0, 1, 201, 195, 128, 1, 0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140, 74,
      ...> 197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175
      ...> >>
      ...> |> TransactionMovement.deserialize()
      {
        %TransactionMovement{
          to: <<0, 0, 214, 107, 17, 107, 227, 11, 17, 43, 204, 48, 78, 129, 145, 126, 45, 68, 194,
            159, 19, 92, 240, 29, 37, 105, 183, 232, 56, 42, 163, 236, 251, 186>>,
          amount: 30_000_000,
          type: {:NFT, <<0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140, 74,
                        197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175>>}
        },
        ""
      }
  """
  @spec deserialize(bitstring()) :: {t(), bitstring}
  def deserialize(data) do
    {address, <<amount::64, rest::bitstring>>} = Utils.deserialize_address(data)
    {type, rest} = Type.deserialize(rest)

    {
      %__MODULE__{
        to: address,
        amount: amount,
        type: type
      },
      rest
    }
  end

  @spec from_map(map()) :: t()
  def from_map(movement = %{}) do
    res = %__MODULE__{
      to: Map.get(movement, :to),
      amount: Map.get(movement, :amount)
    }

    case Map.get(movement, :type) do
      :UCO ->
        %{res | type: :UCO}

      {:NFT, nft_address} ->
        %{res | type: {:NFT, nft_address}}
    end
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{to: to, amount: amount, type: :UCO}) do
    %{
      to: to,
      amount: amount,
      type: "UCO"
    }
  end

  def to_map(%__MODULE__{to: to, amount: amount, type: {:NFT, nft_address}}) do
    %{
      to: to,
      amount: amount,
      type: "NFT",
      nft_address: nft_address
    }
  end
end
