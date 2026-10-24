import SwiftUI
import UIKit

struct MetricCard: View {
  let title: String
  let value: String
  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title).font(.subheadline).foregroundStyle(.secondary)
      Text(value).font(.title2.weight(.semibold).monospacedDigit()).minimumScaleFactor(0.8)
        .lineLimit(1)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
      .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 16))
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
  static let appBackground = Color(UIColor.systemGroupedBackground)
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
