import EconopolisCore
import Foundation

enum MoneyInput {
  static func cents(_ text: String) -> Money? {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(
      of: ",", with: "")
    guard normalized.range(of: "^[0-9]+(?:\\.[0-9]{1,2})?$", options: .regularExpression) != nil,
      let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    else { return nil }
    let amount = NSDecimalNumber(decimal: decimal).multiplying(by: 100)
    guard amount.compare(0) != .orderedAscending,
      amount.compare(1_000_000_000) != .orderedDescending
    else { return nil }
    return amount.int64Value
  }
  static func dollars(_ cents: Money) -> String {
    NSDecimalNumber(value: cents).dividing(by: 100).stringValue
  }
}
