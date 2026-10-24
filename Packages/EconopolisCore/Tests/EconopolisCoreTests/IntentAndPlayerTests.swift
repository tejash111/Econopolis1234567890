import Foundation
import Testing
@testable import EconopolisCore

@Suite("Offline intents and fictional participation")
struct IntentAndPlayerTests {
    @Test func parserRequiresConfirmationAndConvertsUnits() async throws {
        let engine = SimulationEngine(); let context = IntentContext(update: try await engine.createWorld())
        let intent = SimulationIntentParser.parse("Increase interest rates by 2 percentage points", context: context)
        #expect(intent.requiresConfirmation)
        if case .policy(let policy) = intent { #expect(policy.rateBasisPoints == 600); try SimulationCommandValidator.validate(intent, context: context) } else { Issue.record("Rate command not parsed") }
        let recession = SimulationIntentParser.parse("Simulate a recession for 30 days", context: context)
        if case .crisis(let plan) = recession { #expect(plan.kind == .recession && plan.duration == 30) } else { Issue.record("Recession not parsed") }
        let query = SimulationIntentParser.parse("Explain the impact of the bank run", context: context)
        #expect(!query.requiresConfirmation)
        let invalid = SimulationIntentParser.parse("Buy real stocks for me", context: context)
        if case .unsupported = invalid {} else { Issue.record("Unsupported action accepted") }
        let tooLarge = SimulationIntentParser.parse("Provide emergency liquidity 100 million dollars", context: context)
        #expect(throws: SimulationError.self) { try SimulationCommandValidator.validate(tooLarge, context: context) }
        #expect(try await engine.metrics().day == 0)
    }
    @Test func playerIsRealAndReplaysFromSameBaseline() async throws {
        var configuration = SimulationConfiguration(seed: 12, population: 1_001)
        configuration.player = PlayerProfile(name: "Test Citizen", districtID: "district-5", archetypeID: 2, startingDeposit: 400_000)
        let a = SimulationEngine(), b = SimulationEngine()
        _ = try await a.createWorld(configuration: configuration); _ = try await b.createWorld(configuration: configuration)
        let initial = try await a.snapshot()
        #expect(initial.state.households.last?.name == "Test Citizen")
        #expect(initial.state.households.last?.depositBalance == 400_000)
        #expect(initial.state.ledger.reconcile().isBalanced)
        try SnapshotValidator.validate(initial)
        _ = try await a.advance(days: 30); _ = try await b.advance(days: 30)
        #expect(try await a.snapshot() == b.snapshot())
        let evidence = try await a.evidence(id: "household-1000")
        #expect(evidence.transactions.contains { $0.kind == .payroll })
        #expect(evidence.household?.decisions.count == 30)
    }
    @Test func allPoliciesRespectFundingAndAccounting() async throws {
        for kind in PolicyKind.allCases {
            let engine = SimulationEngine(); _ = try await engine.createWorld(configuration: .init(population: 60, businessCount: 6))
            let plan = PolicyPlan(id: kind.id, kind: kind, targetID: kind == .liquidity || kind == .guarantee ? "bank-0" : nil, amount: 1_000_000, day: 1)
            try await engine.schedule(event: .init(id: plan.id, day: plan.day, kind: .policy(plan)))
            _ = try await engine.advance(days: 35)
            let snapshot = try await engine.snapshot()
            #expect(snapshot.state.ledger.reconcile().isBalanced)
            try SnapshotValidator.validate(snapshot)
        }
    }
}
