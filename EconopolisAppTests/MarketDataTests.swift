import Foundation
import Testing

@testable import Econopolis

private let fixtureKey = "CG-unit-test-only-market-key"
private let fixtureCoins = Data(
  #"[{"id":"bitcoin","symbol":"btc","name":"Bitcoin"},{"id":"ethereum","symbol":"eth","name":"Ethereum"}]"#
    .utf8)
private let fixtureQuote = Data(
  #"[{"id":"bitcoin","symbol":"btc","name":"Bitcoin","current_price":100.1250,"market_cap":2000,"total_volume":500,"price_change_percentage_24h":-1.25,"last_updated":"2026-10-24T10:00:00.000Z","sparkline_in_7d":{"price":[100,101,100.125]}}]"#
    .utf8)
private actor FixtureTransport: MarketHTTPTransport {
  var responses: [MarketHTTPResponse]
  var requests: [URLRequest] = []
  init(_ responses: [MarketHTTPResponse]) { self.responses = responses }
  func send(_ request: URLRequest) throws -> MarketHTTPResponse {
    requests.append(request)
    guard !responses.isEmpty else { throw URLError(.badServerResponse) }
    return responses.removeFirst()
  }
}
private func response(_ data: Data, status: Int = 200, retry: String? = nil) -> MarketHTTPResponse {
  MarketHTTPResponse(data: data, status: status, retryAfter: retry)
}
private actor MemoryMarketCredentials: MarketCredentialStore {
  var value: String?
  init(_ value: String? = nil) { self.value = value }
  func read() -> String? { value }
  func save(_ key: String) { value = key }
  func delete() { value = nil }
}
private actor SuspendedCryptoAPI: CryptoMarketDataAPI {
  var pending: CheckedContinuation<[CryptoQuote], Error>?
  func coins(key: String) throws -> [CryptoCoin] {
    try JSONDecoder().decode([CryptoCoin].self, from: fixtureCoins)
  }
  func quotes(ids: [String], key: String) async throws -> [CryptoQuote] {
    try await withCheckedThrowingContinuation { pending = $0 }
  }
  func complete() throws {
    let decoder = JSONDecoder()
    pending?.resume(returning: try decoder.decode([CryptoQuote].self, from: fixtureQuote))
    pending = nil
  }
}
private actor SuspendedDeletingCredentials: MarketCredentialStore {
  var value: String? = fixtureKey
  var pending: CheckedContinuation<Void, Never>?
  func read() -> String? { value }
  func save(_ key: String) { value = key }
  func delete() async { await withCheckedContinuation { pending = $0 } }
  func finishDelete() {
    value = nil
    pending?.resume()
    pending = nil
  }
}
@Suite("Read-only CoinGecko Demo market data", .serialized)
struct MarketDataTests {
  @Test func resolvedIDsBatchGETHeaderAndDecimalParsing() async throws {
    let transport = FixtureTransport([response(fixtureCoins), response(fixtureQuote)])
    let client = CoinGeckoClient(transport: transport)
    let coins = try await client.coins(key: fixtureKey)
    #expect(coins.map(\.id) == ["bitcoin", "ethereum"])
    let quotes = try await client.quotes(ids: coins.map(\.id), key: fixtureKey)
    let quote = try #require(quotes.first)
    #expect(quote.currentPrice == Decimal(string: "100.1250"))
    #expect(quote.priceChangePercentage24h == -1.25)
    #expect(quote.sparklineIn7d?.price.count == 3)
    #expect(quote.updatedAt != nil)
    let requests = await transport.requests
    #expect(requests.count == 2)
    #expect(
      requests.allSatisfy {
        $0.httpMethod == "GET" && $0.httpBody == nil && $0.url?.host == "api.coingecko.com"
          && $0.url?.scheme == "https"
          && $0.value(forHTTPHeaderField: "x-cg-demo-api-key") == fixtureKey
          && $0.value(forHTTPHeaderField: "x-cg-pro-api-key") == nil
          && !$0.url!.absoluteString.contains(fixtureKey)
      })
    #expect(requests[0].url?.path == "/api/v3/coins/list")
    let query = URLComponents(url: requests[1].url!, resolvingAgainstBaseURL: false)!.queryItems!
    #expect(query.contains(.init(name: "ids", value: "bitcoin,ethereum")))
    #expect(query.contains(.init(name: "vs_currency", value: "usd")))
  }
  @Test func missingKeyAndInvalidIDsSendNothing() async throws {
    let transport = FixtureTransport([])
    let client = CoinGeckoClient(transport: transport)
    for key in ["", "CG-bad\nheader-key"] {
      await #expect(throws: CryptoMarketError.missingKey) { _ = try await client.coins(key: key) }
    }
    for ids in [
      [], [""], ["bitcoin,ethereum"], ["bitcoin", "bitcoin"], Array(repeating: "id", count: 9),
    ] {
      await #expect(throws: CryptoMarketError.invalidCoin) {
        _ = try await client.quotes(ids: ids, key: fixtureKey)
      }
    }
    #expect(await transport.requests.isEmpty)
  }
  @Test func missingFieldsAndEmptyResultsStayUnavailable() async throws {
    let client = CoinGeckoClient(
      transport: FixtureTransport([
        response(Data("[]".utf8)),
        response(
          Data(#"[{"id":"bitcoin","symbol":"btc","name":"Bitcoin","current_price":null}]"#.utf8)),
      ]))
    #expect(try await client.quotes(ids: ["bitcoin"], key: fixtureKey).isEmpty)
    let quote = try #require(try await client.quotes(ids: ["bitcoin"], key: fixtureKey).first)
    #expect(quote.currentPrice == nil && quote.sparklineIn7d == nil && quote.isStale(at: .now))
    #expect(cryptoMoney(quote.currentPrice) == "Unavailable")
  }
  @Test func malformedMismatchedNegativeAndDuplicateQuotesRejected() async throws {
    let raw = String(decoding: fixtureQuote, as: UTF8.self)
    for raw in [
      "{}", "null", "", raw.replacingOccurrences(of: "bitcoin", with: "other"),
      raw.replacingOccurrences(of: "100.1250", with: "-1"),
      "[" + raw.dropFirst().dropLast() + "," + raw.dropFirst().dropLast() + "]",
    ] {
      let client = CoinGeckoClient(transport: FixtureTransport([response(Data(raw.utf8))]))
      await #expect(throws: CryptoMarketError.invalidResponse) {
        _ = try await client.quotes(ids: ["bitcoin"], key: fixtureKey)
      }
    }
  }
  @Test func authPlanAndRateLimitErrorsAreSanitized() async throws {
    let fixtures: [(MarketHTTPResponse, CryptoMarketError)] = [
      (response(Data(), status: 401), .invalidKey),
      (
        response(
          Data(#"{"status":{"error_code":10010,"error_message":"private-details"}}"#.utf8),
          status: 400), .wrongPlan
      ),
      (response(Data(#"{"status":{"error_code":10005}}"#.utf8), status: 400), .higherPlan),
      (response(Data(), status: 429, retry: "7200"), .rateLimited(7200)),
      (response(Data(), status: 429), .rateLimited(60)),
      (response(Data(), status: 451), .http(451)),
    ]
    for (fixture, expected) in fixtures {
      let client = CoinGeckoClient(transport: FixtureTransport([fixture]))
      await #expect(throws: expected) { _ = try await client.coins(key: fixtureKey) }
      #expect(!expected.localizedDescription.contains("private-details"))
    }
  }
  @Test func providerTimestampsDetermineStaleness() throws {
    let decoder = JSONDecoder()
    let quote = try #require(decoder.decode([CryptoQuote].self, from: fixtureQuote).first)
    let date = try #require(quote.updatedAt)
    #expect(!quote.isStale(at: date.addingTimeInterval(60)))
    #expect(quote.isStale(at: date.addingTimeInterval(181)))
  }
  @Test @MainActor func missingCredentialsDoesNotContactProvider() async {
    let transport = FixtureTransport([])
    let model = CryptoViewModel(
      client: CoinGeckoClient(transport: transport), credentials: MemoryMarketCredentials(),
      preferences: nil)
    await model.run()
    #expect(!model.hasKey && model.records.isEmpty)
    #expect(await transport.requests.isEmpty)
  }
  @Test func keychainRoundTripUsesIsolatedNamespace() async throws {
    let store = MarketKeyStore(service: "org.econopolis.crypto-tests." + UUID().uuidString)
    try await store.save(fixtureKey)
    #expect(try await store.read() == fixtureKey)
    try await store.save("CG-updated-test-only-key")
    #expect(try await store.read() == "CG-updated-test-only-key")
    try await store.delete()
    #expect(try await store.read() == nil)
  }
  @Test @MainActor func disconnectedSessionRejectsLateQuote() async throws {
    let api = SuspendedCryptoAPI()
    let model = CryptoViewModel(
      client: api, credentials: MemoryMarketCredentials(fixtureKey), preferences: nil)
    let run = Task { await model.run() }
    let deadline = ContinuousClock.now + .seconds(12)
    while await api.pending == nil && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(await api.pending != nil)
    await model.disconnect()
    try await api.complete()
    await run.value
    #expect(!model.hasKey && model.records.isEmpty && model.symbols.isEmpty)
  }
  @Test @MainActor func refreshCannotReloadKeyWhileDisconnecting() async throws {
    let transport = FixtureTransport([])
    let credentials = SuspendedDeletingCredentials()
    let model = CryptoViewModel(
      client: CoinGeckoClient(transport: transport), credentials: credentials, preferences: nil)
    let removing = Task { await model.disconnect() }
    let deadline = ContinuousClock.now + .seconds(12)
    while await credentials.pending == nil && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(await credentials.pending != nil)
    await model.run()
    #expect(await transport.requests.isEmpty)
    await credentials.finishDelete()
    await removing.value
    #expect(!model.hasKey && model.records.isEmpty)
  }
  @Test @MainActor func watchlistUsesResolvedIDsAndBatchesRequests() async throws {
    let transport = FixtureTransport([response(fixtureCoins), response(fixtureQuote)])
    let model = CryptoViewModel(
      client: CoinGeckoClient(transport: transport),
      credentials: MemoryMarketCredentials(fixtureKey), preferences: nil)
    let run = Task { await model.run() }
    let deadline = ContinuousClock.now + .seconds(12)
    while model.records.isEmpty && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.watchlist == ["bitcoin", "ethereum"])
    #expect(model.records["bitcoin"]?.quote?.currentPrice == Decimal(string: "100.1250"))
    #expect(model.records["ethereum"]?.quote == nil)
    model.toggle("not-a-resolved-id")
    #expect(!model.watchlist.contains("not-a-resolved-id"))
    #expect(await transport.requests.count == 2)
    run.cancel()
    await run.value
  }
}
