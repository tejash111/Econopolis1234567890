import EconopolisCore
import Foundation

struct BranchComparisonExport: Codable {
  let seed: UInt64
  let worldA: EconomyMetrics
  let worldB: EconomyMetrics
  let publicClaimsA: Money
  let publicClaimsB: Money
  let unmetWithdrawalAttemptsA: Money
  let unmetWithdrawalAttemptsB: Money
  let warning: String
}
actor ReportExporter {
  func write(branches: BranchUpdate, configuration: SimulationConfiguration) throws -> [URL] {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "EconopolisReports", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var files: [URL] = []
    for (name, update) in [("WorldA", branches.a), ("WorldB", branches.b)] {
      var csv =
        "day,population,employed,labor_force,unemployment_percent,consumer_spending_cents,transaction_volume_cents,household_debt_cents,confidence_percent,system_stress_percent,active_businesses,household_defaults\n"
      for m in update.history {
        csv +=
          "\(m.day),\(m.population),\(m.employed),\(m.laborForce),\(m.unemploymentPercentage),\(m.consumerSpending),\(m.transactionVolume),\(m.aggregateHouseholdDebt),\(m.averageConfidence),\(m.financialStress),\(m.activeBusinesses),\(m.householdDefaults)\n"
      }
      let url = directory.appendingPathComponent("\(name)-metrics.csv")
      try Data(csv.utf8).write(to: url, options: .atomic)
      files.append(url)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let config = directory.appendingPathComponent("WorldA-configuration.json")
    try encoder.encode(configuration).write(to: config, options: .atomic)
    files.append(config)
    let comparison = BranchComparisonExport(
      seed: branches.a.seed, worldA: branches.a.metrics, worldB: branches.b.metrics,
      publicClaimsA: branches.a.crisis?.emergencyClaims ?? 0,
      publicClaimsB: branches.b.crisis?.emergencyClaims ?? 0,
      unmetWithdrawalAttemptsA: branches.a.crisis?.unmetWithdrawals ?? 0,
      unmetWithdrawalAttemptsB: branches.b.crisis?.unmetWithdrawals ?? 0,
      warning:
        "Synthetic educational model. Withdrawal attempts are flows, public claims are stocks. Compare matching simulation days. No real-world forecasting claims."
    )
    let report = directory.appendingPathComponent("comparison.json")
    try encoder.encode(comparison).write(to: report, options: .atomic)
    files.append(report)
    return files
  }
}
