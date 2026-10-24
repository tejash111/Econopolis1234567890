import Foundation
import Testing

@testable import EconopolisCore

@Suite("Crisis correctness", .serialized)
struct CrisisTests {
  @Test func bankRunAndFundedRescue() async throws {
    let session = BranchSession()
    try await session.prepareDemo()
    try await session.runDemoCrisis()
    let unrescued = try await session.update()
    #expect((unrescued.a.crisis?.requestedWithdrawals ?? 0) > 0)
    #expect((unrescued.a.crisis?.unmetWithdrawals ?? 0) > 0)
    #expect(unrescued.a.metrics == unrescued.b.metrics)
    try await session.rewindDemo()
    #expect(try await session.update().b.metrics.day == 7)
    try await session.rescueDemo()
    let result = try await session.update()
    #expect(result.a.metrics.day == result.b.metrics.day)
    #expect((result.b.crisis?.emergencyClaims ?? 0) > 0)
    #expect((result.b.crisis?.unmetWithdrawals ?? 0) < (result.a.crisis?.unmetWithdrawals ?? 0))
    let data = try await session.encode()
    let archive = try JSONDecoder().decode(SessionArchive.self, from: data)
    for snapshot in [archive.a, archive.b] {
      #expect(snapshot.state.ledger.reconcile().isBalanced)
      #expect(snapshot.state.ledger.accounts.values.allSatisfy { $0.balance >= 0 })
      try SnapshotValidator.validate(snapshot)
      for bank in snapshot.state.banks {
        let claim =
          snapshot.state.crisis?.publicLoans.filter { $0.centralBank && $0.borrowerID == bank.id }
          .reduce(Money(0)) { $0 + $1.outstanding } ?? 0
        #expect(
          bank.reserves + bank.performingLoanAssets == bank.depositLiabilities + bank.equity + claim
        )
      }
    }
    print(
      "BANK_RUN_RESULT unmet_A=\(result.a.crisis!.unmetWithdrawals) unmet_B=\(result.b.crisis!.unmetWithdrawals) central_bank_claim=\(result.b.crisis!.emergencyClaims)"
    )
    let restored = BranchSession()
    try await restored.restore(data: data)
    #expect(try await restored.update().b.metrics == result.b.metrics)
  }
  @Test func outageRecoveryAndNoFictionalSales() async throws {
    let engine = SimulationEngine()
    _ = try await engine.createWorld(configuration: .init(population: 60, businessCount: 6))
    let outage = CrisisPlan(id: "outage", kind: .paymentOutage, startDay: 1, duration: 30)
    try await engine.schedule(event: .init(id: outage.id, day: 1, kind: .crisis(outage)))
    _ = try await engine.advance(days: 30)
    let blocked = try await engine.snapshot().state
    #expect(blocked.currentMetrics.consumerSpending == 0)
    #expect(blocked.businesses.allSatisfy { $0.revenue == 0 })
    #expect((blocked.ledger.queuedPayments?.count ?? 0) > 0)
    _ = try await engine.advanceOneDay()
    let recovered = try await engine.snapshot().state
    #expect(recovered.ledger.settledTransactions.contains { $0.kind == .payroll && $0.day == 31 })
    #expect(recovered.ledger.reconcile().isBalanced)
  }
  @Test func allScenarioTypesAndDeterministicReplay() async throws {
    for kind in CrisisKind.allCases {
      let a = SimulationEngine()
      let b = SimulationEngine()
      _ = try await a.createWorld(configuration: .init(population: 60, businessCount: 6))
      let plan = CrisisPlan(
        id: kind.id, kind: kind, targetID: kind == .bankRun ? "bank-0" : nil, severity: 8_000,
        startDay: 1, duration: 5)
      try await a.schedule(event: .init(id: plan.id, day: 1, kind: .crisis(plan)))
      let initial = try await a.snapshot()
      try await b.restore(snapshot: initial)
      _ = try await a.advance(days: 12)
      _ = try await b.advance(days: 12)
      #expect(try await a.snapshot() == b.snapshot())
      #expect(try await a.snapshot().state.ledger.reconcile().isBalanced)
    }
  }
  @Test func invalidPlansAndPublicLoanRepayment() async throws {
    #expect(throws: SimulationError.self) {
      try CrisisPlan(id: "x", kind: .bankRun, startDay: -1).validate()
    }
    #expect(throws: SimulationError.self) {
      try PolicyPlan(id: "x", kind: .liquidity, amount: -1, day: 1).validate()
    }
    let engine = SimulationEngine()
    _ = try await engine.createWorld()
    let policy = PolicyPlan(
      id: "liquidity", kind: .liquidity, targetID: "bank-0", amount: 12_000_000, day: 1)
    try await engine.schedule(event: .init(id: policy.id, day: 1, kind: .policy(policy)))
    _ = try await engine.advance(days: 32)
    let s = try await engine.snapshot().state
    #expect(s.crisis!.emergencyClaims < policy.amount)
    #expect(s.ledger.supplyChanges?.contains { $0.amount < 0 } == true)
    #expect(s.ledger.reconcile().isBalanced)
  }
  @Test func yearWithShocks() async throws {
    let engine = SimulationEngine()
    _ = try await engine.createWorld()
    for (index, kind) in CrisisKind.allCases.enumerated() {
      let plan = CrisisPlan(
        id: "stress-\(index)", kind: kind, targetID: kind == .bankRun ? "bank-0" : nil,
        severity: 6_000, startDay: 10 + index * 35, duration: 14)
      try await engine.schedule(event: .init(id: plan.id, day: plan.startDay, kind: .crisis(plan)))
    }
    let start = ContinuousClock.now
    _ = try await engine.advance(days: 365)
    let snapshot = try await engine.snapshot()
    #expect(snapshot.state.day == 365 && snapshot.state.ledger.reconcile().isBalanced)
    #expect(snapshot.state.history.allSatisfy { $0.financialStress.isFinite })
    #expect(snapshot.state.crisis!.records.count <= 600)
    try SnapshotValidator.validate(snapshot)
    print(
      "YEAR_WITH_SHOCKS duration=\(ContinuousClock.now - start) transactions=\(snapshot.state.ledger.settledTransactions.count)"
    )
  }
  @Test func keyedBranchReplayAndRateExpiration() async throws {
    let session = BranchSession()
    try await session.create(configuration: .init(population: 60, businessCount: 6))
    let plan = CrisisPlan(
      id: "matched-rate", kind: .interestRate, startDay: 2, duration: 3, rateBasisPoints: 1_200)
    try await session.scheduleCrisis(plan)
    for _ in 0..<8 { try await session.step() }
    let future = try await session.update()
    #expect(future.a.metrics == future.b.metrics)
    let data = try await session.encode()
    let archive = try JSONDecoder().decode(SessionArchive.self, from: data)
    #expect(archive.a.state == archive.b.state)
    #expect(archive.a.state.centralBank.annualRateBasisPoints != 1_200)
    try await session.seek(day: 1)
    for _ in 0..<7 { try await session.step() }
    #expect(try await session.update().a.metrics == future.a.metrics)
  }
  @Test func corruptCheckpointDoesNotPartiallyRestoreBranches() async throws {
    let session = BranchSession()
    try await session.create(configuration: .init(population: 60, businessCount: 6))
    let original = try await session.encode()
    var archive = try JSONDecoder().decode(SessionArchive.self, from: original)
    let engine = SimulationEngine()
    _ = try await engine.createWorld(configuration: .init(population: 60, businessCount: 6))
    var bad = try await engine.snapshot()
    bad.state.day = -1
    archive.baseline = bad
    await #expect(throws: SimulationError.self) {
      try await session.restore(data: JSONEncoder().encode(archive))
    }
    #expect(try await session.update().a.metrics.day == 0)
    #expect(try await session.update().b.metrics.day == 0)
  }

  @Test func expiredBankRunReleasesOperationalSuspension() async throws {
    let engine = SimulationEngine()
    _ = try await engine.createWorld(configuration: .init(population: 60, businessCount: 6))
    let plan = CrisisPlan(
      id: "short-run", kind: .bankRun, targetID: "bank-0", severity: 10_000, startDay: 1,
      duration: 6)
    try await engine.schedule(event: .init(id: plan.id, day: 1, kind: .crisis(plan)))
    _ = try await engine.advance(days: 7)
    let state = try await engine.snapshot().state
    #expect(state.crisis!.pressure["bank-0"] == 0)
    #expect(!state.crisis!.suspendedBanks.contains("bank-0"))
    #expect(state.ledger.reconcile().isBalanced)
  }

}
