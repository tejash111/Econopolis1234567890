import SwiftUI
import UIKit

struct MetricCard: View {
  let title: String
  let value: String
  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
      Text(value).font(.title3.weight(.semibold).monospacedDigit()).minimumScaleFactor(0.65)
        .lineLimit(1)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
      .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 18))
      .accessibilityElement(children: .combine)
  }
}
func money(_ cents: Int64) -> String {
  (Double(cents) / 100).formatted(.currency(code: "USD").precision(.fractionLength(2)))
}
func compactMoney(_ cents: Int64) -> String {
  if abs(cents) < 100_000 {
    return (Double(cents) / 100).formatted(.currency(code: "USD").precision(.fractionLength(0)))
  }
  return (Double(cents) / 100).formatted(
    .currency(code: "USD").notation(.compactName).precision(.fractionLength(1)))
}
func percent(_ value: Double) -> String {
  value.formatted(.number.precision(.fractionLength(1))) + "%"
}
extension Color {
  static let cityNight = Color(
    UIColor {
      $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.035, green: 0.055, blue: 0.08, alpha: 1)
        : UIColor(red: 0.94, green: 0.95, blue: 0.96, alpha: 1)
    })
  static let cardSurface = Color(UIColor.secondarySystemGroupedBackground)
}
extension View {
  @ViewBuilder func economicGlass(interactive: Bool = false) -> some View {
    if #available(iOS 26, *) {
      self.glassEffect(.regular.interactive(interactive), in: .rect(cornerRadius: 22))
    } else {
      self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
  }
  @ViewBuilder func glassGroup() -> some View {
    if #available(iOS 26, *) { GlassEffectContainer(spacing: 12) { self } } else { self }
  }
}
struct EmptyFinancialState: View {
  let title: String
  let detail: String
  var body: some View {
    ContentUnavailableView(title, systemImage: "chart.bar.xaxis", description: Text(detail))
      .padding(.vertical)
  }
}
