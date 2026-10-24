import EconopolisCore
import Foundation

enum EconomyChartMetric: String, CaseIterable, Identifiable {
  case spending = "Consumer spending"
  case employment = "Employed"
  case unemployment = "Unemployment"
  case debt = "Household debt"
  case transactions = "Transaction volume"
  case confidence = "Confidence"
  case stress = "System stress"
  case banks = "Bank stress"
  case businesses = "Active firms"
  var id: String { rawValue }
  var supportsDistrict: Bool { self == .spending || self == .employment || self == .businesses }
  var monetary: Bool { self == .spending || self == .debt || self == .transactions }
  func value(_ m: EconomyMetrics, district: String = "") -> Double {
    if !district.isEmpty, supportsDistrict, let d = m.districts.first(where: { $0.id == district })
    {
      switch self {
      case .spending: return Double(d.consumerSpending) / 100
      case .employment: return Double(d.employed)
      default: return Double(d.activeBusinesses)
      }
    }
    switch self {
    case .spending: return Double(m.consumerSpending) / 100
    case .employment: return Double(m.employed)
    case .unemployment: return m.unemploymentPercentage
    case .debt: return Double(m.aggregateHouseholdDebt) / 100
    case .transactions: return Double(m.transactionVolume) / 100
    case .confidence: return m.averageConfidence
    case .stress: return m.financialStress
    case .banks: return m.bankLiquidityStress
    case .businesses: return Double(m.activeBusinesses)
    }
  }
}
struct ChartSample: Identifiable, Equatable {
  let day: Int
  let value: Double
  var id: Int { day }
}
enum ChartProjection {
  static func samples(
    history: [EconomyMetrics], metric: EconomyChartMetric, range: Int, district: String = ""
  ) -> [ChartSample] {
    let end = history.last?.day ?? 0
    return history.filter { range == 0 || $0.day >= end - range + 1 }.map {
      ChartSample(day: $0.day, value: metric.value($0, district: district))
    }
  }
}
