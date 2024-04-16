defmodule Archethic.P2P.Message.ValidateSmartContractCall do
  @moduledoc """
  Represents a message to validate a smart contract call
  """

  @enforce_keys [:recipient, :transaction, :timestamp]
  defstruct [:recipient, :transaction, :timestamp]

  alias Archethic.Contracts.Contract.ActionWithoutTransaction
  alias Archethic.Contracts
  alias Archethic.Contracts.Contract
  alias Archethic.Contracts.Contract.Context
  alias Archethic.Contracts.Contract.Failure
  alias Archethic.Contracts.Contract.ConditionRejected
  alias Archethic.Contracts.Contract.ActionWithTransaction
  alias Archethic.Contracts.Contract.ConditionRejected
  alias Archethic.Contracts.Contract.Failure
  alias Archethic.Crypto
  alias Archethic.Mining
  alias Archethic.OracleChain
  alias Archethic.P2P.Message.SmartContractCallValidation
  alias Archethic.TransactionChain
  alias Archethic.TransactionChain.Transaction
  alias Archethic.TransactionChain.Transaction.ValidationStamp

  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations.VersionedUnspentOutput

  alias Archethic.TransactionChain.TransactionData.Recipient

  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations.TransactionMovement

  alias Archethic.UTXO

  @type t :: %__MODULE__{
          recipient: Recipient.t(),
          transaction: Transaction.t(),
          timestamp: DateTime.t()
        }

  @doc """
  Serialize message into binary
  """
  @spec serialize(t()) :: bitstring()
  def serialize(%__MODULE__{
        recipient: recipient,
        transaction: tx = %Transaction{},
        timestamp: timestamp
      }) do
    tx_version = Transaction.version()
    recipient_bin = Recipient.serialize(recipient, tx_version)

    <<recipient_bin::bitstring, Transaction.serialize(tx)::bitstring,
      DateTime.to_unix(timestamp, :millisecond)::64>>
  end

  @doc """
  Deserialize the encoded message
  """
  @spec deserialize(bitstring()) :: {t(), bitstring()}
  def deserialize(data) when is_bitstring(data) do
    tx_version = Transaction.version()
    {recipient, rest} = Recipient.deserialize(data, tx_version)
    {tx, <<timestamp::64, rest::bitstring>>} = Transaction.deserialize(rest)

    {
      %__MODULE__{
        recipient: recipient,
        transaction: tx,
        timestamp: DateTime.from_unix!(timestamp, :millisecond)
      },
      rest
    }
  end

  @spec process(t(), Crypto.key()) :: SmartContractCallValidation.t()
  def process(
        msg = %__MODULE__{
          recipient: %Recipient{address: recipient_address},
          transaction: %Transaction{address: tx_address},
          timestamp: timestamp
        },
        _
      ) do
    # We use job cache to reduce the number of times the contract is executed by the same node
    Archethic.Utils.JobCache.get!(
      {:smart_contract_validation, recipient_address, tx_address,
       DateTime.to_unix(timestamp, :millisecond)},
      function: fn -> validate_smart_contract_call(msg) end,
      timeout: 3_000,
      # We set the maximum timeout for a transaction to be processed before the kill the cache
      ttl: 60_000
    )
  end

  defp validate_smart_contract_call(%__MODULE__{
         recipient: recipient = %Recipient{address: recipient_address},
         transaction: transaction = %Transaction{},
         timestamp: datetime
       }) do
    # During the validation of a call there is no validation_stamp yet.
    # We need one because the contract might want to access transaction.timestamp
    # which is bound to validation_stamp.timestamp
    transaction = %Transaction{
      transaction
      | validation_stamp: ValidationStamp.generate_dummy(timestamp: datetime)
    }

    unspent_outputs =
      Archethic.get_unspent_outputs(recipient_address)
      |> VersionedUnspentOutput.wrap_unspent_outputs(Mining.protocol_version())
      |> Context.filter_inputs()
      |> VersionedUnspentOutput.unwrap_unspent_outputs()

    with {:ok, contract_tx} <- get_last_transaction(recipient_address),
         {:ok, contract} <- parse_contract(contract_tx),
         trigger = Contract.get_trigger_for_recipient(recipient),
         :ok <-
           execute_condition(trigger, contract, transaction, recipient, datetime, unspent_outputs),
         {:ok, execution_result} <-
           execute_trigger(trigger, contract, transaction, recipient, unspent_outputs, datetime) do
      fee = calculate_fee(execution_result, contract, datetime)

      if enough_funds_to_send?(execution_result, unspent_outputs, fee) do
        %SmartContractCallValidation{
          status: :ok,
          fee: fee
        }
      else
        %SmartContractCallValidation{
          status: {:error, :insufficient_funds},
          fee: 0
        }
      end
    else
      error_status -> %SmartContractCallValidation{status: error_status, fee: 0}
    end
  end

  defp get_last_transaction(address) do
    case TransactionChain.get_last_transaction(address) do
      {:ok, tx} -> {:ok, tx}
      {:error, _} -> {:error, :transaction_not_exists}
    end
  end

  defp parse_contract(contract_tx) do
    case Contracts.from_transaction(contract_tx) do
      {:ok, contract} -> {:ok, contract}
      {:error, reason} -> {:error, :parsing_error, reason}
    end
  end

  defp execute_condition(trigger, contract, transaction, recipient, datetime, unspent_outputs) do
    case Contracts.execute_condition(
           trigger,
           contract,
           transaction,
           recipient,
           datetime,
           unspent_outputs
         ) do
      {:ok, _} -> :ok
      {:error, failure = %Failure{}} -> {:error, :invalid_execution, failure}
      {:error, %ConditionRejected{subject: subject}} -> {:error, :invalid_condition, subject}
    end
  end

  defp execute_trigger(trigger, contract, transaction, recipient, unspent_outputs, datetime) do
    case Contracts.execute_trigger(trigger, contract, transaction, recipient, unspent_outputs,
           time_now: datetime
         ) do
      {:ok, result} -> {:ok, result}
      {:error, failure = %Failure{}} -> {:error, :invalid_execution, failure}
    end
  end

  defp calculate_fee(
         %ActionWithTransaction{next_tx: next_tx, encoded_state: encoded_state},
         contract = %Contract{transaction: %Transaction{address: contract_address}},
         timestamp
       ) do
    index = TransactionChain.get_size(contract_address)

    case Contract.sign_next_transaction(contract, next_tx, index) do
      {:ok, tx} ->
        previous_usd_price =
          timestamp
          |> OracleChain.get_last_scheduling_date()
          |> OracleChain.get_uco_price()
          |> Keyword.fetch!(:usd)

        # Here we use a nil contract_context as we return the fees the user has to pay for the contract
        Mining.get_transaction_fee(tx, nil, previous_usd_price, timestamp, encoded_state)

      _ ->
        0
    end
  end

  defp calculate_fee(_, _, _), do: 0

  defp enough_funds_to_send?(%ActionWithTransaction{next_tx: tx}, inputs, fee) do
    %{uco: uco_balance, token: token_balances} = UTXO.get_balance(inputs)

    tx
    |> Transaction.get_movements()
    |> Enum.reduce(%{uco: fee}, fn
      %TransactionMovement{type: :UCO, amount: amount}, acc ->
        Map.update!(acc, :uco, &(&1 + amount))

      %TransactionMovement{type: {:token, token_address, token_id}, amount: amount}, acc ->
        Map.update(acc, {:token, {token_address, token_id}}, amount, &(amount + &1))
    end)
    |> Enum.all?(fn
      {:uco, uco_to_spend} ->
        uco_balance >= uco_to_spend

      {{:token, token}, amount} ->
        Map.get(token_balances, token) >= amount
    end)
  end

  defp enough_funds_to_send?(%ActionWithoutTransaction{}, inputs, fee) do
    %{uco: uco_balance} = UTXO.get_balance(inputs)
    uco_balance >= fee
  end
end
