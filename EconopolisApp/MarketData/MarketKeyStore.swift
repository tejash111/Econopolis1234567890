import Foundation
import Security

protocol MarketCredentialStore: Sendable {
  func read() async throws -> String?
  func save(_ key: String) async throws
  func delete() async throws
}
actor MarketKeyStore: MarketCredentialStore {
  private let service: String
  private let account: String
  init(service: String? = nil, account: String = "coingecko-demo-market-data") {
    self.account = account
    self.service =
      service ?? (Bundle.main.bundleIdentifier ?? "org.econopolis.app") + ".coingecko-demo"
      + (ProcessInfo.processInfo.arguments.contains("-econopolis-ui-testing") ? ".ui-tests" : "")
  }
  private var query: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
  func read() throws -> String? {
    var query = query
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data,
      let key = String(data: data, encoding: .utf8)
    else { throw KeyError.access(status) }
    return key
  }
  func save(_ key: String) throws {
    let values: [String: Any] = [
      kSecValueData as String: Data(key.utf8),
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]
    let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
    if status == errSecItemNotFound {
      var entry = query
      values.forEach { entry[$0.key] = $0.value }
      let added = SecItemAdd(entry as CFDictionary, nil)
      guard added == errSecSuccess else { throw KeyError.access(added) }
    } else if status != errSecSuccess {
      throw KeyError.access(status)
    }
  }
  func delete() throws {
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeyError.access(status)
    }
  }
  enum KeyError: Error, LocalizedError {
    case access(OSStatus)
    var errorDescription: String? {
      switch self {
      case .access(let status):
        "Secure key storage is unavailable (OSStatus \(status)). Unlock the device and run a correctly signed app."
      }
    }
  }
}
