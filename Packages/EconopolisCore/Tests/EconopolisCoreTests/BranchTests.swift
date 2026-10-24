import Foundation
import Testing
@testable import EconopolisCore

@Suite("Independent mobile worlds")
struct BranchTests {
    @Test func branchIsolationReplayAndArchive() async throws {
        let session = BranchSession(), baseline = SimulationEngine()
        let config = SimulationConfiguration(seed: 93, population: 120, businessCount: 12)
        try await session.create(configuration: config); _ = try await baseline.createWorld(configuration: config)
        try await session.intervene(.confidenceShock(basisPoints: -4_000))
        for _ in 0..<12 { try await session.step() }
        _ = try await baseline.advance(days: 12)
        let result = try await session.update()
        let baselineMetrics = try await baseline.metrics()
        #expect(result.a.metrics == baselineMetrics)
        #expect(result.a.metrics.consumerSpending != result.b.metrics.consumerSpending)
        #expect(result.a.metrics.day == result.b.metrics.day)
        try await session.seek(day: 3)
        #expect(try await session.update().a.metrics.day == 3)
        try await session.seek(day: 12)
        let replay = try await session.update()
        #expect(replay.a.metrics == result.a.metrics && replay.b.metrics == result.b.metrics)
        let data = try await session.encode(), restored = BranchSession()
        try await restored.restore(data: data)
        try await restored.step(); try await session.step()
        let x = try await restored.update(), y = try await session.update()
        #expect(x.a.metrics == y.a.metrics && x.b.metrics == y.b.metrics)
        let saved = try await session.encode()
        let archive = try JSONDecoder().decode(SessionArchive.self, from: saved)
        #expect(archive.a.state.ledger.reconcile().isBalanced && archive.b.state.ledger.reconcile().isBalanced)
    }
    @Test func interventionValidationAndReset() async throws {
        let session = BranchSession()
        try await session.create(configuration: .init(population: 12, businessCount: 6))
        let initial = try await session.update()
        try await session.intervene(.interestRate(basisPoints: 1_500)); try await session.step()
        #expect(try await session.update().a.centralBank.annualRateBasisPoints == 400)
        #expect(try await session.update().b.centralBank.annualRateBasisPoints == 1_500)
        try await session.reset()
        #expect(try await session.update().a.metrics == initial.a.metrics)
        #expect(try await session.update().b.metrics == initial.b.metrics)
        do { try await session.seek(day: 99); Issue.record("Accepted unseen timeline day") } catch {}
        let engine = SimulationEngine(); _ = try await engine.createWorld()
        do { try await engine.schedule(event: .init(id: "past", day: 0, kind: .interestRate(basisPoints: 0))); Issue.record("Accepted past event") } catch {}
    }
    @Test func measuredNinetyDayBenchmark() async throws {
        let engine = SimulationEngine()
        _ = try await engine.createWorld()
        let start = ContinuousClock.now
        _ = try await engine.advance(days: 90)
        let elapsed = ContinuousClock.now - start
        let state = try await engine.snapshot().state
        print("ECONOPOLIS_BENCHMARK population=\(state.households.count) days=90 duration=\(elapsed) settled=\(state.ledger.settledTransactions.count)")
        #expect(state.day == 90 && state.ledger.reconcile().isBalanced)
    }
}
