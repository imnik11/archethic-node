defmodule Archethic.DB.EmbeddedImpl.ChainReader do
  @moduledoc false

  alias Archethic.DB.EmbeddedImpl.ChainIndex
  alias Archethic.DB.EmbeddedImpl.ChainWriter
  alias Archethic.DB.EmbeddedImpl.Encoding

  alias Archethic.TransactionChain.Transaction
  alias Archethic.Utils

  @page_size 10

  @spec get_transaction(address :: binary(), fields :: list(), db_path :: String.t()) ::
          {:ok, Transaction.t()} | {:error, :transaction_not_exists}
  def get_transaction(address, fields, db_path) do
    case ChainIndex.get_tx_entry(address, db_path) do
      {:error, :not_exists} ->
        {:error, :transaction_not_exists}

      {:ok, %{offset: offset, genesis_address: genesis_address}} ->
        filepath = ChainWriter.chain_path(db_path, genesis_address)

        # Open the file as the position from the transaction in the chain file
        fd = File.open!(filepath, [:binary, :read])
        :file.position(fd, offset)

        {:ok, <<size::32, version::32>>} = :file.pread(fd, offset, 8)
        column_names = fields_to_column_names(fields)

        # Read the transaction and extract requested columns from the fields arg
        tx =
          read_transaction(fd, column_names, size, 0)
          |> Enum.reduce(%{version: version}, fn {column, data}, acc ->
            Encoding.decode(version, column, data, acc)
          end)
          |> Utils.atomize_keys()
          |> Transaction.from_map()

        :file.close(fd)

        {:ok, tx}
    end
  end

  @spec get_transaction_chain(
          address :: binary(),
          fields :: list(),
          opts :: list(),
          db_path :: String.t()
        ) ::
          {transactions_by_page :: list(Transaction.t()), more? :: boolean(),
           paging_state :: nil | binary()}
  def get_transaction_chain(address, fields, opts, db_path) do
    case ChainIndex.get_tx_entry(address, db_path) do
      {:error, :not_exists} ->
        {[], false, ""}

      {:ok, %{genesis_address: genesis_address}} ->
        filepath = ChainWriter.chain_path(db_path, genesis_address)
        fd = File.open!(filepath, [:binary, :read])

        # Set the file cursor position to the paging state
        position =
          case Keyword.get(opts, :paging_state) do
            nil ->
              :file.position(fd, 0)
              0

            paging_address ->
              {:ok, %{offset: offset, size: size}} =
                ChainIndex.get_tx_entry(paging_address, db_path)

              :file.position(fd, offset + size)
              offset + size
          end

        column_names = fields_to_column_names(fields)

        # Read the transactions until the nb of transactions to fullfil the page (ie. 10 transactions)
        {transactions, more?, paging_state} = scan_chain(fd, column_names, position)
        :file.close(fd)
        {transactions, more?, paging_state}
    end
  end

  defp read_transaction(fd, fields, limit, position, acc \\ %{})

  defp read_transaction(_fd, _fields, limit, position, acc) when limit == position, do: acc

  defp read_transaction(fd, fields, limit, position, acc) do
    case :file.read(fd, 1) do
      {:ok, <<column_name_size::8>>} ->
        {:ok, <<value_size::32>>} = :file.read(fd, 4)

        {:ok, <<column_name::binary-size(column_name_size), value::binary-size(value_size)>>} =
          :file.read(fd, column_name_size + value_size)

        position = position + 5 + column_name_size + value_size

        # Without field selection we take all the fields of the transaction
        if fields == [] do
          read_transaction(fd, fields, limit, position, Map.put(acc, column_name, value))
        else
          # Check if we need to take this field based on the selection criteria
          if column_name in fields do
            read_transaction(fd, fields, limit, position, Map.put(acc, column_name, value))
          else
            # We continue to the next as the selection critieria didn't match
            read_transaction(fd, fields, limit, position, acc)
          end
        end

      :eof ->
        acc
    end
  end

  defp scan_chain(fd, fields, position, acc \\ []) do
    case :file.read(fd, 8) do
      {:ok, <<size::32, version::32>>} ->
        if length(acc) == @page_size do
          %Transaction{address: address} = List.first(acc)
          {Enum.reverse(acc), true, address}
        else
          data = read_transaction(fd, fields, size, 0)

          tx =
            data
            |> Enum.reduce(%{version: version}, fn {column, data}, acc ->
              Encoding.decode(version, column, data, acc)
            end)
            |> Utils.atomize_keys()
            |> Transaction.from_map()

          scan_chain(fd, fields, position + 8 + size, [tx | acc])
        end

      :eof ->
        {Enum.reverse(acc), false, nil}
    end
  end

  @doc """

  ## Examples

      iex> ChainReader.fields_to_column_names([:address, :previous_public_key, validation_stamp: [:timestamp]])
      [
         "address",
         "previous_public_key",
         "validation_stamp.timestamp"
      ]
      
      iex> ChainReader.fields_to_column_names([:address, :previous_public_key, validation_stamp: [ledger_operations: [:fee,  :transaction_movements]]])
      [
         "address",
         "previous_public_key",
         "validation_stamp.ledger_operations.transaction_movements",
         "validation_stamp.ledger_operations.fee",
      ]
      
      iex> ChainReader.fields_to_column_names([
      ...>  :address, 
      ...>  :previous_public_key, 
      ...>  data: [:content], 
      ...>  validation_stamp: [
      ...>    :timestamp, 
      ...>    ledger_operations: [ :fee,  :transaction_movements ]
      ...>  ]
      ...> ])
      [
         "address",
         "previous_public_key",
         "data.content",
         "validation_stamp.ledger_operations.transaction_movements",
         "validation_stamp.ledger_operations.fee",
         "validation_stamp.timestamp"
      ]
  """
  @spec fields_to_column_names(list()) :: list(binary())
  def fields_to_column_names(_fields, acc \\ [], prepend \\ "")

  def fields_to_column_names([{k, v} | rest], acc, prepend = "") do
    fields_to_column_names(
      rest,
      List.flatten([fields_to_column_names(v, [], Atom.to_string(k)) | acc]),
      prepend
    )
  end

  def fields_to_column_names([{k, v} | rest], acc, prepend) do
    nested_prepend = "#{prepend}.#{Atom.to_string(k)}"

    fields_to_column_names(
      rest,
      [fields_to_column_names(v, [], nested_prepend) | acc],
      prepend
    )
  end

  def fields_to_column_names([key | rest], acc, prepend = "") do
    fields_to_column_names(rest, [Atom.to_string(key) | acc], prepend)
  end

  def fields_to_column_names([key | rest], acc, prepend) do
    fields_to_column_names(rest, ["#{prepend}.#{Atom.to_string(key)}" | acc], prepend)
  end

  def fields_to_column_names([], acc, _prepend) do
    Enum.reverse(acc)
  end

  def fields_to_column_names(field, acc, prepend) do
    fields_to_column_names([], ["#{prepend}.#{Atom.to_string(field)}" | acc])
  end
end
