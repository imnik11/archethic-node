File.rm_rf!(Archethic.Utils.mut_dir())

ExUnit.start(
  exclude: [:infrastructure, :CI, :CD, :oracle_provider, :benchmark],
  timeout: :infinity,
  max_failures: 1
)

Mox.defmock(MockClient, for: Archethic.P2P.Client)

Mox.defmock(MockCrypto,
  for: [Archethic.Crypto.NodeKeystore, Archethic.Crypto.SharedSecretsKeystore]
)

Mox.defmock(MockDB, for: Archethic.DB)
Mox.defmock(MockGeoIP, for: Archethic.P2P.GeoPatch.GeoIP)
Mox.defmock(MockUCOPriceProvider, for: Archethic.OracleChain.Services.UCOPrice.Providers.Impl)

Mox.defmock(MockMetricsCollector, for: Archethic.Metrics.Collector)
