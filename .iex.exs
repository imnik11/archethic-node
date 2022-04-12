IEx.configure(inspect: [limit: :infinity])

alias ArchEthic.Crypto
alias ArchEthic.DB
alias ArchEthic.P2P
alias ArchEthic.P2P.Node
alias ArchEthic.SharedSecrets
alias ArchEthic.Account
alias ArchEthic.Election
alias ArchEthic.Governance
alias ArchEthic.Contracts
alias ArchEthic.TransactionChain
alias ArchEthic.TransactionChain.Transaction
alias ArchEthic.TransactionChain.TransactionData
alias ArchEthic.BeaconChain
alias ArchEthic.Contracts.Interpreter
x = fn -> """

   condition inherit: [

      content: get_genesis_address(\"000000008CBF3D1FCE5D2E270738F3DF62D4A220E3C8D74964625BB219AD1936AD3A579B\"),

      origin_family: biometric

   ]

   actions triggered_by: datetime, at: 1601039923 do

     set_type hosting

     set_content \"Mr.X: 10, Mr.Y: 8\"

   end

""" |> Contracts.parse!() end

y = fn ->

Interpreter.execute({{:., [line: 2],
[
   {:__aliases__, [alias: ArchEthic.Contracts.Interpreter.Library],
    [:Library]},
   :get_genesis_address
 ]}, [line: 2],
[{:get_in, [line: 2], [{:scope, [line: 2], nil}, ["content"]]}]}, %{ "content" => "000000008CBF3D1FCE5D2E270738F3DF62D4A220E3C8D74964625BB219AD1936AD3A579B" })
end
z = fn ->

Interpreter.execute({{:., [line: 2],
[
   {:__aliases__, [alias: ArchEthic.Contracts.Interpreter.Library],
    [:Library]},
   :get_genesis_address
 ]}, [line: 2],
[{:get_in, [line: 2], [{:scope, [line: 2], nil}, ["content"]]}]}, %{ "content" => "000000008CBF3D1FCE5D2E270738F3DF62D4A220E3C8D74964625BB219AD1936AD3A579B" })
end
