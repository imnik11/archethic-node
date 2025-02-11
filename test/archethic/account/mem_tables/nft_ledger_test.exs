defmodule Archethic.Account.MemTables.NFTLedgerTest do
  use ExUnit.Case

  alias Archethic.Account.MemTables.NFTLedger

  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput
  alias Archethic.TransactionChain.TransactionInput

  doctest NFTLedger
end
