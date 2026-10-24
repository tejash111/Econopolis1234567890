import Foundation
import Testing

@testable import Econopolis

private let fixtureKey = "unit-test-only-market-key"
private let fixtureQuote = Data(
  #"{"symbol":"AAPL","bidPrice":"100.1250","askPrice":"100.1300","bidSize":100,"askSize":200}"#.utf8
)
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
private actor SuspendedStocksAPI: StocksMarketDataAPI {
  var pending: CheckedContinuation<StockQuote?, Error>?
  func exchangeInfo(key: String) -> [StockSymbol] {
    [
      StockSymbol(
        symbol: "AAPL", tradability: "BUY_SELL", overnightSupported: nil, fractionable: nil,
        extendedSession: nil)
    ]
  }
  func quote(symbol: String, key: String) async throws -> StockQuote? {
    try await withCheckedThrowingContinuation { pending = $0 }
  }
  func complete() throws {
    pending?.resume(returning: try JSONDecoder().decode(StockQuote.self, from: fixtureQuote))
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
@Suite("Read-only Binance market data", .serialized)
struct MarketDataTests {
  @Test func validGETHeaderAndExactDecimalParsing() async throws {
    let info = Data(
      #"{"timezone":"UTC","symbols":[{"symbol":"MSFT","tradability":"BUY_SELL"},{"symbol":"AAPL","tradability":"BUY_SELL"}]}"#
        .utf8)
    let transport = FixtureTransport([response(info), response(fixtureQuote)])
    let client = BinanceStocksClient(transport: transport)
    #expect(try await client.exchangeInfo(key: fixtureKey).map(\.symbol) == ["AAPL", "MSFT"])
    let quote = try #require(try await client.quote(symbol: "aapl", key: fixtureKey))
    #expect(quote.bid == Decimal(string: "100.1250"))
    #expect(quote.ask == Decimal(string: "100.1300"))
    let requests = await transport.requests
    #expect(requests.count == 2)
    #expect(
      requests.allSatisfy {
        $0.httpMethod == "GET" && $0.httpBody == nil && $0.url?.host == "api.binance.com"
          && $0.url?.scheme == "https"
      })
    #expect(requests[0].value(forHTTPHeaderField: "X-MBX-APIKEY") == fixtureKey)
    #expect(requests[1].url?.query == "symbol=AAPL")
    #expect(!requests[1].url!.absoluteString.contains(fixtureKey))
  }
  @Test func missingKeyOrInvalidSymbolSendsNothing() async throws {
    let transport = FixtureTransport([])
    let client: BinanceStocksClient
    client = BinanceStocksClient(transport: transport)
    await #expect(throws: StockMarketError.missingKey) {
      _ = try await client.exchangeInfo(key: "")
    }
    await #expect(throws: StockMarketError.missingKey) {
      _ = try await client.exchangeInfo(key: "bad\nheader-key")
    }
    await #expect(throws: StockMarketError.invalidSymbol) {
      _ = try await client.quote(symbol: "AAPL&signature=bad", key: fixtureKey)
    }
    #expect(await transport.requests.isEmpty)
  }
  @Test func emptyAndNullQuotesRemainUnavailable() async throws {
    let client = BinanceStocksClient(
      transport: FixtureTransport([
        response(Data()), response(Data(" \n".utf8)), response(Data("null".utf8)),
      ]))
    for _ in 0..<3 { #expect(try await client.quote(symbol: "AAPL", key: fixtureKey) == nil) }
  }
  @Test func malformedMismatchedAndNegativeQuotesAreRejected() async throws {
    for data in [
      Data("{}".utf8),
      Data(
        String(decoding: fixtureQuote, as: UTF8.self).replacingOccurrences(of: "AAPL", with: "MSFT")
          .utf8),
      Data(
        String(decoding: fixtureQuote, as: UTF8.self).replacingOccurrences(
          of: "100.1250", with: "-1"
        ).utf8),
    ] {
      let client = BinanceStocksClient(transport: FixtureTransport([response(data)]))
      await #expect(throws: StockMarketError.invalidResponse) {
        _ = try await client.quote(symbol: "AAPL", key: fixtureKey)
      }
    }
  }
  @Test func authenticationErrorsAndRateLimitAreExplicit() async throws {
    let errors = FixtureTransport([
      response(
        Data(#"{"code":-2014,"msg":"private-detail-must-not-be-displayed"}"#.utf8), status: 400),
      response(Data(), status: 429, retry: "7200"), response(Data(), status: 451),
    ])
    let client = BinanceStocksClient(transport: errors)
    await #expect(throws: StockMarketError.invalidKey) {
      _ = try await client.exchangeInfo(key: fixtureKey)
    }
    await #expect(throws: StockMarketError.rateLimited(7200)) {
      _ = try await client.exchangeInfo(key: fixtureKey)
    }
    await #expect(throws: StockMarketError.http(451)) {
      _ = try await client.exchangeInfo(key: fixtureKey)
    }
    #expect(!StockMarketError.invalidKey.localizedDescription.contains("private-detail"))
  }
  @Test @MainActor func missingCredentialsDoesNotContactProvider() async {
    let transport = FixtureTransport([])
    let model = StocksViewModel(
      client: BinanceStocksClient(transport: transport), credentials: MemoryMarketCredentials(),
      preferences: nil)
    await model.run()
    #expect(!model.hasKey && model.records.isEmpty && model.symbols.isEmpty)
    #expect(await transport.requests.isEmpty)
  }
  @Test func keychainRoundTripUsesIsolatedTestNamespace() async throws {
    let store = MarketKeyStore(service: "org.econopolis.market-tests." + UUID().uuidString)
    try await store.save(fixtureKey)
    #expect(try await store.read() == fixtureKey)
    try await store.save("updated-test-only-key")
    #expect(try await store.read() == "updated-test-only-key")
    try await store.delete()
    #expect(try await store.read() == nil)
  }
  @Test @MainActor func disconnectedSessionRejectsLateQuote() async throws {
    let api = SuspendedStocksAPI()
    let credentials = MemoryMarketCredentials(fixtureKey)
    let model = StocksViewModel(client: api, credentials: credentials, preferences: nil)
    let run = Task { await model.run() }
    let deadline = ContinuousClock.now + .seconds(3)
    while await api.pending == nil && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(await api.pending != nil)
    await model.disconnect()
    try await api.complete()
    await run.value
    #expect(!model.hasKey && model.records.isEmpty && model.symbols.isEmpty)
    #expect(await credentials.read() == nil)
  }
  @Test @MainActor func watchlistIsBoundedAndUsesOnlyProviderSymbols() async throws {
    let stocks = (0..<10).map {
      StockSymbol(
        symbol: "STK\($0)", tradability: "BUY_SELL", overnightSupported: nil, fractionable: nil,
        extendedSession: nil)
    }
    let encoded = try JSONEncoder().encode(StockExchangeInfo(timezone: "UTC", symbols: stocks))
    let transport = FixtureTransport([
      response(encoded), response(Data()), response(Data()), response(Data()),
    ])
    let model = StocksViewModel(
      client: BinanceStocksClient(transport: transport),
      credentials: MemoryMarketCredentials(fixtureKey), preferences: nil)
    let run = Task { await model.run() }
    let deadline = ContinuousClock.now + .seconds(3)
    while model.symbols.isEmpty && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    for symbol in stocks.dropFirst(3) { model.toggle(symbol.symbol) }
    model.toggle("NOT-LISTED")
    #expect(model.watchlist.count == 8 && !model.watchlist.contains("NOT-LISTED"))
    run.cancel()
    await run.value
  }
  @Test @MainActor func refreshCannotReloadKeyWhileDisconnecting() async throws {
    let transport = FixtureTransport([])
    let credentials = SuspendedDeletingCredentials()
    let model = StocksViewModel(
      client: BinanceStocksClient(transport: transport), credentials: credentials, preferences: nil)
    let removing = Task { await model.disconnect() }
    let deadline = ContinuousClock.now + .seconds(3)
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

}
