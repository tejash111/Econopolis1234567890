import Foundation

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
      throw CryptoMarketError.invalidResponse
    }
    return MarketHTTPResponse(
      data: data, status: response.statusCode,
      retryAfter: response.value(forHTTPHeaderField: "Retry-After"))
  }
}
