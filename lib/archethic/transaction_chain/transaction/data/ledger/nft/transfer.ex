defmodule Archethic.TransactionChain.TransactionData.NFTLedger.Transfer do
  @moduledoc """
  Represents a NFT ledger transfer
  """
  defstruct [:to, :amount, :nft, conditions: []]

  alias Archethic.Utils

  @typedoc """
  Transfer is composed from:
  - nft: NFT address
  - to: receiver address of the asset
  - amount: specify the number of NFT to transfer to the recipients (in the smallest unit 10^-8)
  - conditions: specify to which address the NFT can be used
  """
  @type t :: %__MODULE__{
          nft: binary(),
          to: binary(),
          amount: non_neg_integer(),
          conditions: list(binary())
        }

  @doc """
  Serialize NFT transfer into binary format

  ## Examples

      iex> %Transfer{
      ...>   nft:  <<0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140, 74,
      ...>    197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175>>,
      ...>   to: <<0, 0, 104, 134, 142, 120, 40, 59, 99, 108, 63, 166, 143, 250, 93, 186, 216, 117,
      ...>    85, 106, 43, 26, 120, 35, 44, 137, 243, 184, 160, 251, 223, 0, 93, 14>>,
      ...>   amount: 1_050_000_000
      ...> }
      ...> |> Transfer.serialize()
      <<
        # NFT address
        0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140, 74,
        197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175,
        # Transfer recipient
        0, 0, 104, 134, 142, 120, 40, 59, 99, 108, 63, 166, 143, 250, 93, 186, 216, 117,
        85, 106, 43, 26, 120, 35, 44, 137, 243, 184, 160, 251, 223, 0, 93, 14,
        # Transfer amount
        0, 0, 0, 0, 62, 149, 186, 128
      >>
  """
  def serialize(%__MODULE__{nft: nft, to: to, amount: amount}) do
    <<nft::binary, to::binary, amount::64>>
  end

  @doc """
  Deserialize an encoded NFT transfer

  ## Examples

      iex> <<
      ...> 0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140, 74,
      ...> 197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175,
      ...> 0, 0, 104, 134, 142, 120, 40, 59, 99, 108, 63, 166, 143, 250, 93, 186, 216, 117,
      ...> 85, 106, 43, 26, 120, 35, 44, 137, 243, 184, 160, 251, 223, 0, 93, 14,
      ...> 0, 0, 0, 0, 62, 149, 186, 128>>
      ...> |> Transfer.deserialize()
      {
        %Transfer{
          nft: <<0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140, 74,
            197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175>>,
          to: <<0, 0, 104, 134, 142, 120, 40, 59, 99, 108, 63, 166, 143, 250, 93, 186, 216, 117,
            85, 106, 43, 26, 120, 35, 44, 137, 243, 184, 160, 251, 223, 0, 93, 14>>,
          amount: 1_050_000_000
        },
        ""
      }
  """
  @spec deserialize(bitstring()) :: {t(), bitstring}
  def deserialize(data) do
    {nft_address, rest} = Utils.deserialize_address(data)
    {recipient_address, <<amount::64, rest::bitstring>>} = Utils.deserialize_address(rest)

    {
      %__MODULE__{
        nft: nft_address,
        to: recipient_address,
        amount: amount
      },
      rest
    }
  end

  @spec from_map(map()) :: t()
  def from_map(transfer = %{}) do
    %__MODULE__{
      nft: Map.get(transfer, :nft),
      to: Map.get(transfer, :to),
      amount: Map.get(transfer, :amount)
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{nft: nft, to: to, amount: amount}) do
    %{
      nft: nft,
      to: to,
      amount: amount
    }
  end
end
