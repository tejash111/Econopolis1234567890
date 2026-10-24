import Foundation

struct CryptoCoin: Codable, Sendable, Equatable, Identifiable {
  let id: String
  let symbol: String
  let name: String
}
struct CryptoQuote: Codable, Sendable, Equatable, Identifiable {
  let id: String
  let symbol: String
  let name: String
  let currentPrice: Decimal?
  let marketCap: Decimal?
  let totalVolume: Decimal?
  let priceChangePercentage24h: Double?
  let lastUpdated: String?
  let sparklineIn7d: Sparkline?
  enum CodingKeys: String, CodingKey {
    case id, symbol, name
    case currentPrice = "current_price"
    case marketCap = "market_cap"
    case totalVolume = "total_volume"
    case priceChangePercentage24h = "price_change_percentage_24h"
    case lastUpdated = "last_updated"
    case sparklineIn7d = "sparkline_in_7d"
  }
  struct Sparkline: Codable, Sendable, Equatable { let price: [Double] }
  var updatedAt: Date? {
    guard let lastUpdated else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: lastUpdated) ?? ISO8601DateFormatter().date(from: lastUpdated)
  }
  func isStale(at date: Date) -> Bool {
    guard let updatedAt else { return true }
    return date.timeIntervalSince(updatedAt) > 180 || updatedAt.timeIntervalSince(date) > 60
  }
}
enum CryptoMarketError: Error, LocalizedError, Sendable, Equatable {
  case missingKey, invalidKey, invalidCoin, invalidResponse, wrongPlan, higherPlan
  case http(Int)
  case rateLimited(Int)
  var errorDescription: String? {
    switch self {
    case .missingKey: "Enter a CoinGecko Demo API key."
    case .invalidKey:
      "CoinGecko rejected this Demo API key. Check the key in your developer dashboard."
    case .invalidCoin: "Choose a coin from the CoinGecko catalog."
    case .invalidResponse: "CoinGecko returned an unexpected response. No prices were substituted."
    case .wrongPlan: "This connection requires a Demo key. Pro keys use a different API service."
    case .higherPlan: "CoinGecko reports that this request requires a higher plan."
    case .rateLimited(let seconds):
      "CoinGecko limited requests. Retrying after at least \(seconds) seconds."
    case .http(let status): "CoinGecko is unavailable (HTTP \(status)). Try again later."
    }
  }
  static func validKey(_ key: String) -> Bool {
    key.hasPrefix("CG-") && (8...512).contains(key.utf8.count)
      && key.utf8.allSatisfy { (33...126).contains($0) }
  }
}
protocol CryptoMarketDataAPI: Sendable {
  func coins(key: String) async throws -> [CryptoCoin]
  func quotes(ids: [String], key: String) async throws -> [CryptoQuote]
}
/// Shared across screen lifetimes so rapid navigation cannot bypass request spacing.
private actor CryptoRequestGate {
  static let shared = CryptoRequestGate()
  private var next = ContinuousClock.now
  func acquire() async throws {
    while ContinuousClock.now < next {
      try await Task.sleep(until: next, clock: .continuous)
    }
    try Task.checkCancellation()
    next = .now + .seconds(3)
  }
}
/// Demo tier is explicit. No automatic tier detection, trading, or simulation dependency.
actor CoinGeckoClient: CryptoMarketDataAPI {
  private let transport: any MarketHTTPTransport
  init(transport: any MarketHTTPTransport = URLSessionMarketTransport()) {
    self.transport = transport
  }
  func coins(key: String) async throws -> [CryptoCoin] {
    let data = try await get("coins/list", key: key, query: [])
    guard let coins = try? JSONDecoder().decode([CryptoCoin].self, from: data),
      coins.allSatisfy({ Self.validID($0.id) && !$0.name.isEmpty && !$0.symbol.isEmpty }),
      Set(coins.map(\.id)).count == coins.count
    else { throw CryptoMarketError.invalidResponse }
    return coins.sorted { $0.id < $1.id }
  }
  func quotes(ids: [String], key: String) async throws -> [CryptoQuote] {
    guard !ids.isEmpty, ids.count <= 8, Set(ids).count == ids.count,
      ids.allSatisfy(Self.validID)
    else { throw CryptoMarketError.invalidCoin }
    let data = try await get(
      "coins/markets", key: key,
      query: [
        .init(name: "vs_currency", value: "usd"),
        .init(name: "ids", value: ids.joined(separator: ",")),
        .init(name: "sparkline", value: "true"), .init(name: "precision", value: "full"),
      ])
    let decoder = JSONDecoder()
    guard let quotes = try? decoder.decode([CryptoQuote].self, from: data),
      Set(quotes.map(\.id)).count == quotes.count,
      quotes.allSatisfy({ quote in
        ids.contains(quote.id) && !quote.name.isEmpty && !quote.symbol.isEmpty
          && [quote.currentPrice, quote.marketCap, quote.totalVolume].allSatisfy {
            $0.map { !$0.isNaN && $0 >= 0 } ?? true
          }
          && (quote.priceChangePercentage24h.map(\.isFinite) ?? true)
          && (quote.sparklineIn7d?.price.allSatisfy { $0.isFinite && $0 >= 0 } ?? true)
      })
    else { throw CryptoMarketError.invalidResponse }
    return quotes
  }
  static func validID(_ id: String) -> Bool {
    !id.isEmpty && id.utf8.count <= 200 && !id.contains(",")
      && !id.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
  }
  private func get(_ path: String, key: String, query: [URLQueryItem]) async throws -> Data {
    guard CryptoMarketError.validKey(key) else { throw CryptoMarketError.missingKey }
    var url = URLComponents(string: "https://api.coingecko.com/api/v3/\(path)")!
    if !query.isEmpty { url.queryItems = query }
    var request = URLRequest(
      url: url.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    request.httpMethod = "GET"
    request.setValue(key, forHTTPHeaderField: "x-cg-demo-api-key")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    try await CryptoRequestGate.shared.acquire()
    let response = try await transport.send(request)
    try Task.checkCancellation()
    if response.status == 429 {
      var seconds = Int(response.retryAfter ?? "") ?? 60
      if let raw = response.retryAfter, Int(raw) == nil {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: raw) { seconds = Int(ceil(date.timeIntervalSinceNow)) }
      }
      throw CryptoMarketError.rateLimited(max(60, seconds))
    }
    struct Failure: Decodable {
      let status: Status?
      struct Status: Decodable { let error_code: Int? }
    }
    if let code = (try? JSONDecoder().decode(Failure.self, from: response.data))?.status?.error_code
    {
      switch code {
      case 10010, 10011: throw CryptoMarketError.wrongPlan
      case 10005: throw CryptoMarketError.higherPlan
      case 10002, 10003: throw CryptoMarketError.invalidKey
      default: throw CryptoMarketError.invalidResponse
      }
    }
    guard (200...299).contains(response.status) else {
      if response.status == 401 { throw CryptoMarketError.invalidKey }
      throw CryptoMarketError.http(response.status)
    }
    return response.data
  }
}
