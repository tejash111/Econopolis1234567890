import Foundation
import Observation

struct StockQuoteRecord: Sendable {
  var quote: StockQuote?
  var fetchedAt: Date?
  var error: String?
}
@MainActor @Observable final class StocksViewModel {
  private(set) var symbols: [StockSymbol] = []
  private(set) var records: [String: StockQuoteRecord] = [:]
  private(set) var hasKey = false
  private(set) var isLoading = false
  private(set) var error: String?
  private(set) var revision = 0
  private(set) var cooldownUntil: Date?
  var paused = false
  private(set) var watchlist: [String]
  @ObservationIgnored private var disconnecting = false
  @ObservationIgnored private let client: any StocksMarketDataAPI
  @ObservationIgnored private let credentials: any MarketCredentialStore
  @ObservationIgnored private let preferences: UserDefaults?
  init(
    client: any StocksMarketDataAPI = BinanceStocksClient(),
    credentials: any MarketCredentialStore = MarketKeyStore(),
    preferences: UserDefaults? = .standard
  ) {
    self.client = client
    self.credentials = credentials
    self.preferences = preferences
    var seen: Set<String> = []
    watchlist = Array(
      (preferences?.stringArray(forKey: "stockWatchlist") ?? []).filter(
        { BinanceStocksClient.validSymbol($0) && seen.insert($0).inserted }
      ).prefix(8))
  }
  func saveKey(_ input: String) async -> Bool {
    let key = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard StockMarketError.validKey(key) else {
      error = "Enter a valid API key without spaces or line breaks."
      return false
    }
    do {
      try await credentials.save(key)
      revision += 1
      hasKey = true
      symbols = []
      records = [:]
      error = nil
      cooldownUntil = nil
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
  func disconnect() async {
    disconnecting = true
    revision += 1
    defer {
      disconnecting = false
      revision += 1
    }
    do {
      try await credentials.delete()
      hasKey = false
      symbols = []
      records = [:]
      error = nil
      cooldownUntil = nil
    } catch { self.error = error.localizedDescription }
  }
  func toggle(_ symbol: String) {
    guard symbols.contains(where: { $0.symbol == symbol }) else { return }
    if watchlist.contains(symbol) {
      watchlist.removeAll { $0 == symbol }
      records[symbol] = nil
    } else if watchlist.count < 8 {
      watchlist.append(symbol)
    }
    preferences?.set(watchlist, forKey: "stockWatchlist")
    revision += 1
  }
  func retry() {
    error = nil
    revision += 1
  }
  /// Owned by SwiftUI .task; cancellation on navigation/background stops the sole refresh loop.
  func run() async {
    guard !disconnecting else { return }
    let token = revision
    defer { if revision == token { isLoading = false } }
    do {
      guard let key = try await credentials.read() else {
        if revision == token { hasKey = false }
        return
      }
      guard revision == token, !Task.isCancelled else { return }
      hasKey = true
      if let until = cooldownUntil, until > .now {
        try await waitUntil(until)
      }
      guard revision == token, !Task.isCancelled else { return }
      error = nil
      cooldownUntil = nil
      if symbols.isEmpty {
        isLoading = true
        let result = try await client.exchangeInfo(key: key)
        guard revision == token, !Task.isCancelled else { return }
        symbols = result
        let valid = Set(result.map(\.symbol))
        watchlist = watchlist.filter { valid.contains($0) }
        if watchlist.isEmpty {
          let preferred = ["AAPL", "MSFT", "NVDA"].filter { valid.contains($0) }
          watchlist = preferred.isEmpty ? Array(result.prefix(3).map(\.symbol)) : preferred
          preferences?.set(watchlist, forKey: "stockWatchlist")
        }
        isLoading = false
      }
      guard !watchlist.isEmpty else { return }
      while !Task.isCancelled && revision == token {
        let deadline = ContinuousClock.now + .seconds(5)
        await refresh(key: key, token: token)
        guard revision == token, !Task.isCancelled else { return }
        if error != nil { break }
        try await Task.sleep(until: deadline, clock: .continuous)
      }
    } catch is CancellationError {} catch {
      guard revision == token, !Task.isCancelled else { return }
      record(error)
    }
    if revision == token { isLoading = false }
    if let until = cooldownUntil, until > .now {
      do { try await waitUntil(until) } catch { return }
      guard revision == token, !Task.isCancelled else { return }
      cooldownUntil = nil
      error = nil
      revision += 1
    }

  }
  private func waitUntil(_ date: Date) async throws {
    while date > .now { try await Task.sleep(for: .seconds(min(3_600, date.timeIntervalSinceNow))) }
  }
  private func refresh(
    key: String, token: Int
  ) async {
    for symbol in watchlist {
      guard revision == token, !Task.isCancelled else { return }
      do {
        let quote = try await client.quote(symbol: symbol, key: key)
        guard revision == token, !Task.isCancelled else { return }
        records[symbol] = StockQuoteRecord(quote: quote, fetchedAt: .now)
      } catch is CancellationError { return } catch {
        guard revision == token, !Task.isCancelled else { return }
        var previous = records[symbol] ?? StockQuoteRecord()
        previous.error = Self.message(error)
        records[symbol] = previous
        if let failure = error as? StockMarketError {
          switch failure {
          case .rateLimited, .invalidKey, .http(403), .http(451):
            record(failure)
            return
          default: break
          }
        }
      }
    }
  }
  private func record(_ error: Error) {
    self.error = Self.message(error)
    if case StockMarketError.rateLimited(let seconds) = error {
      cooldownUntil = .now.addingTimeInterval(Double(seconds))
    }
  }
  private static func message(_ error: Error) -> String {
    if let error = error as? StockMarketError { return error.localizedDescription }
    if let error = error as? MarketKeyStore.KeyError { return error.localizedDescription }
    return "Could not reach Binance. Check your connection and try again. No price was substituted."
  }
}
