import Foundation

struct StockSymbol: Codable, Sendable, Equatable, Identifiable {
  let symbol: String
  let tradability: String
  let overnightSupported: Bool?
  let fractionable: Bool?
  let extendedSession: Bool?
  var id: String { symbol }
}
struct StockExchangeInfo: Codable, Sendable {
  let timezone: String
  let symbols: [StockSymbol]
}
struct StockQuote: Codable, Sendable, Equatable {
  let symbol: String
  let bidPrice: String
  let askPrice: String
  let bidSize: Int64
  let askSize: Int64
  var bid: Decimal? { Self.decimal(bidPrice) }
  var ask: Decimal? { Self.decimal(askPrice) }
  static func decimal(_ string: String) -> Decimal? {
    guard !string.isEmpty, string.utf8.allSatisfy({ (48...57).contains($0) || $0 == 46 }),
      string.filter({ $0 == "." }).count <= 1,
      let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN
    else { return nil }
    return value
  }
}
enum StockMarketError: Error, LocalizedError, Sendable, Equatable {
  case missingKey, invalidKey, invalidSymbol, invalidResponse
  case http(Int)
  case rateLimited(Int)
  var errorDescription: String? {
    switch self {
    case .missingKey: "Add your Binance market-data API key to request quotes."
    case .invalidKey:
      "The API key was rejected or lacks access to this market-data service. Check the key and its restrictions."
    case .invalidSymbol: "Choose a valid stock symbol from the exchange list."
    case .invalidResponse:
      "Binance returned an unexpected market-data response. No price was substituted."
    case .rateLimited(let seconds):
      "Binance limited requests. Updates will retry after at least \(seconds) seconds."
    case .http(451): "Binance reports that this service is unavailable from this location."
    case .http(403):
      "Binance denied access. Check account eligibility, API restrictions and regional availability."
    case .http(let status): "Market data is unavailable (HTTP \(status)). Try again later."
    }
  }
  static func validKey(_ key: String) -> Bool {
    (8...512).contains(key.utf8.count) && key.utf8.allSatisfy { (33...126).contains($0) }
  }
}
struct MarketHTTPResponse: Sendable {
  let data: Data
  let status: Int
  let retryAfter: String?
}
protocol MarketHTTPTransport: Sendable {
  func send(_ request: URLRequest) async throws -> MarketHTTPResponse
}
/// Never forward the API-key header to a redirect destination.
private final class MarketRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
struct URLSessionMarketTransport: MarketHTTPTransport {
  private let session: URLSession
  init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.timeoutIntervalForRequest = 15
    session = URLSession(
      configuration: configuration, delegate: MarketRedirectPolicy(), delegateQueue: nil)
  }
  func send(_ request: URLRequest) async throws -> MarketHTTPResponse {
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw StockMarketError.invalidResponse
    }
    return MarketHTTPResponse(
      data: data, status: response.statusCode,
      retryAfter: response.value(forHTTPHeaderField: "Retry-After"))
  }
}
protocol StocksMarketDataAPI: Sendable {
  func exchangeInfo(key: String) async throws -> [StockSymbol]
  func quote(symbol: String, key: String) async throws -> StockQuote?
}
/// Read-only external reference data. This client has no trading/account endpoints or simulation dependency.
actor BinanceStocksClient: StocksMarketDataAPI {
  private let transport: any MarketHTTPTransport
  init(transport: any MarketHTTPTransport = URLSessionMarketTransport()) {
    self.transport = transport
  }
  func exchangeInfo(key: String) async throws -> [StockSymbol] {
    let data = try await get("exchangeInfo", key: key)
    guard let info = try? JSONDecoder().decode(StockExchangeInfo.self, from: data),
      info.symbols.allSatisfy({ Self.validSymbol($0.symbol) }),
      Set(info.symbols.map(\.symbol)).count == info.symbols.count
    else { throw StockMarketError.invalidResponse }
    return info.symbols.sorted { $0.symbol < $1.symbol }
  }
  func quote(symbol: String, key: String) async throws -> StockQuote? {
    let ticker = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard Self.validSymbol(ticker) else { throw StockMarketError.invalidSymbol }
    let data = try await get("quote", key: key, symbol: ticker)
    let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    if text == "" || text == "null" { return nil }
    guard let quote = try? JSONDecoder().decode(StockQuote.self, from: data),
      quote.symbol == ticker, quote.bid != nil, quote.ask != nil, quote.bidSize >= 0,
      quote.askSize >= 0
    else { throw StockMarketError.invalidResponse }
    return quote
  }
  static func validSymbol(_ symbol: String) -> Bool {
    (1...20).contains(symbol.utf8.count)
      && symbol.utf8.allSatisfy {
        (65...90).contains($0) || (48...57).contains($0) || $0 == 46 || $0 == 45
      }
  }
  private func get(_ endpoint: String, key: String, symbol: String? = nil) async throws -> Data {
    guard StockMarketError.validKey(key) else { throw StockMarketError.missingKey }
    var components = URLComponents(
      string: "https://api.binance.com/sapi/v1/equity/market/\(endpoint)")!
    if let symbol { components.queryItems = [URLQueryItem(name: "symbol", value: symbol)] }
    var request = URLRequest(
      url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    request.httpMethod = "GET"
    request.setValue(key, forHTTPHeaderField: "X-MBX-APIKEY")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let response = try await transport.send(request)
    try Task.checkCancellation()
    if response.status == 429 || response.status == 418 {
      let cooldown = max(5, Int(response.retryAfter ?? "") ?? 60)
      throw StockMarketError.rateLimited(cooldown)
    }
    struct APIError: Decodable { let code: Int }
    if let error = try? JSONDecoder().decode(APIError.self, from: response.data), error.code < 0 {
      // Never display a raw provider message, which could contain account/key details.
      if error.code == -2014 || error.code == -2015 { throw StockMarketError.invalidKey }
      if (200...299).contains(response.status) { throw StockMarketError.invalidResponse }
    }
    guard (200...299).contains(response.status) else {
      if response.status == 401 { throw StockMarketError.invalidKey }
      throw StockMarketError.http(response.status)
    }
    return response.data
  }
}
