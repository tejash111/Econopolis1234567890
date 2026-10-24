import Foundation
import Testing
@testable import EconopolisCore

@Suite("ECONOPOLIS foundation")
struct EngineTests {
    @Test func exactPopulationAndResolvedReferences() throws {
        let state = try WorldGenerator.create(configuration: .init())
        #expect(state.households.count == 1_000)
        #expect(state.businesses.count == 80)
        #expect(state.banks.count == 4)
        #expect(state.districts.count == 6)
        #expect(state.archetypes.count == 12)
        #expect(Set(state.households.map(\.personalVariation)).count > 100)
        #expect(state.centralBank.id == "central-bank")
        try SnapshotValidator.validate(SimulationSnapshot(state: state))
    }
    @Test func reproducibleSeedAndCommands() async throws {
        let a = SimulationEngine(), b = SimulationEngine()
        _ = try await a.createWorld(configuration: .init(seed: 17, population: 100, businessCount: 12))
        _ = try await b.createWorld(configuration: .init(seed: 17, population: 100, businessCount: 12))
        _ = try await a.advance(days: 35); _ = try await b.advance(days: 35)
        let sa = try await a.snapshot(), sb = try await b.snapshot()
        #expect(sa == sb)
    }
    @Test func differentSeedsVary() throws {
        let a = try WorldGenerator.create(configuration: .init(seed: 1))
        let b = try WorldGenerator.create(configuration: .init(seed: 2))
        #expect(a.households != b.households)
        #expect(a.random != b.random)
    }
    @Test func knownRandomSequence() {
        var random = SplitMix64(seed: 0)
        #expect(random.next() == 0xE220A8397B1DCDAF)
        #expect(random.next() == 0x6E789E6AA1B965F4)
    }
    @Test func ledgerRejectionsAndReconciliation() throws {
        var ledger = Ledger()
        try ledger.open(.init(id: "a", ownerID: "alice", bankID: nil, kind: .cash, balance: 100))
        try ledger.open(.init(id: "b", ownerID: "bob", bankID: nil, kind: .cash, balance: 0))
        #expect(ledger.transfer(from: "a", to: "b", amount: 30, kind: .essential, day: 1).settled)
        #expect(ledger.transfer(from: "a", to: "b", amount: 100, kind: .essential, day: 1).rejection == .insufficientFunds)
        #expect(ledger.transfer(from: "absent", to: "b", amount: 1, kind: .essential, day: 1).rejection == .missingAccount)
        #expect(ledger.transfer(from: "a", to: "b", amount: -1, kind: .essential, day: 1).rejection == .invalidAmount)
        #expect(ledger.transfer(from: "a", to: "b", amount: 0, kind: .essential, day: 1).rejection == .invalidAmount)
        #expect(ledger.transfer(from: "a", to: "a", amount: 1, kind: .essential, day: 1).rejection == .sameAccount)
        #expect(ledger.balance("a") == 70 && ledger.balance("b") == 30)
        #expect(ledger.entries.count == 2 && ledger.rejectedTransactions.count == 5)
        #expect(ledger.reconcile().isBalanced)
    }
    @Test func openingLoansAndBankBalanceSheets() throws {
        let s = try WorldGenerator.create(configuration: .init())
        #expect(!s.loans.isEmpty)
        for loan in s.loans {
            #expect(loan.outstandingPrincipal == loan.originalPrincipal)
            #expect(loan.intervalDays == 30 && loan.nextPaymentDay == 30 && loan.maturityDay == 360)
            #expect(loan.installmentPrincipal * 12 >= loan.originalPrincipal)
            #expect(s.ledger.settledTransactions.contains { $0.kind == .loanAdvance && $0.recipient == loan.borrowerAccountID && $0.amount == loan.originalPrincipal })
        }
        for bank in s.banks {
            #expect(bank.reserves + bank.performingLoanAssets == bank.depositLiabilities + bank.equity)
            #expect(bank.reserves >= bank.depositLiabilities)
        }
        #expect(s.ledger.reconcile().isBalanced)
    }
    @Test func consumptionPayrollAndLoanServicing() async throws {
        let engine = SimulationEngine()
        _ = try await engine.createWorld()
        _ = try await engine.advance(days: 30)
        let s = try await engine.snapshot().state
        #expect(s.ledger.settledTransactions.contains { $0.kind == .essential && $0.day == 1 })
        #expect(s.ledger.settledTransactions.contains { $0.kind == .discretionary })
        #expect(s.ledger.settledTransactions.contains { $0.kind == .payroll && $0.day == 30 })
        #expect(s.ledger.settledTransactions.contains { $0.kind == .tax })
        #expect(s.ledger.settledTransactions.contains { $0.kind == .benefit })
        #expect(s.ledger.settledTransactions.contains { $0.kind == .interest })
        #expect(s.loans.contains { $0.outstandingPrincipal < $0.originalPrincipal })
        #expect(s.businesses.contains { $0.revenue > 0 && $0.expenses > 0 })
        #expect(s.treasury.taxCollected > 0 && s.treasury.benefitsPaid > 0)
        #expect(s.ledger.reconcile().isBalanced)
    }
    @Test func derivedMetricsMatchActualState() async throws {
        let engine = SimulationEngine()
        _ = try await engine.createWorld(); _ = try await engine.advanceOneDay()
        let s = try await engine.snapshot().state, m = try await engine.metrics()
        let daily = s.ledger.settledTransactions.filter { $0.day == s.day }
        #expect(m.population == s.households.count)
        #expect(m.employed == s.households.filter { $0.employment == .employed }.count)
        #expect(m.transactionVolume == daily.reduce(0) { $0 + $1.amount })
        #expect(m.consumerSpending == daily.filter { $0.kind == .essential || $0.kind == .discretionary }.reduce(0) { $0 + $1.amount })
        #expect(m.aggregateHouseholdDebt == s.households.reduce(0) { $0 + $1.debt })
        #expect(m.districts.reduce(0) { $0 + $1.consumerSpending } == m.consumerSpending)
        #expect(m.districts.reduce(0) { $0 + $1.population } == 1_000)
        #expect(s.history.last == m)
    }
    @Test func resetRestoresBaseline() async throws {
        let engine = SimulationEngine()
        _ = try await engine.createWorld(configuration: .init(seed: 81))
        let baseline = try await engine.snapshot()
        _ = try await engine.advance(days: 5); _ = try await engine.reset()
        #expect(try await engine.snapshot() == baseline)
        _ = try await engine.reset(seed: 82)
        #expect(try await engine.snapshot().state.households != baseline.state.households)
    }
    @Test func snapshotRoundTripAndContinuation() async throws {
        let a = SimulationEngine(), b = SimulationEngine()
        _ = try await a.createWorld(configuration: .init(population: 60, businessCount: 6))
        _ = try await a.advance(days: 7)
        let snapshot = try await a.snapshot()
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SimulationSnapshot.self, from: encoded)
        #expect(decoded == snapshot)
        try await b.restore(snapshot: decoded)
        _ = try await a.advance(days: 25); _ = try await b.advance(days: 25)
        #expect(try await a.snapshot() == b.snapshot())
    }
    @Test func ninetyDayEntireEconomy() async throws {
        let engine = SimulationEngine()
        _ = try await engine.createWorld()
        let initial = try await engine.snapshot().state
        _ = try await engine.advance(days: 90)
        let s = try await engine.snapshot().state
        #expect(s.day == 90 && s.history.count == 91)
        #expect(s.ledger.settledTransactions.count > 90_000)
        #expect(s.households != initial.households)
        #expect(s.currentMetrics.aggregateHouseholdDebt != initial.currentMetrics.aggregateHouseholdDebt)
        #expect(s.currentMetrics.averageConfidence != initial.currentMetrics.averageConfidence)
        #expect(zip(s.businesses, initial.businesses).contains { $0.operatingBalance != $1.operatingBalance })
        #expect(s.ledger.reconcile().isBalanced)
        #expect(s.ledger.accounts.values.allSatisfy { $0.balance >= 0 })
        for metric in s.history {
            #expect(metric.financialStress.isFinite && metric.unemploymentPercentage.isFinite && metric.averageConfidence.isFinite)
            #expect((0...100).contains(metric.financialStress))
        }
        for bank in s.banks { #expect(bank.reserves + bank.performingLoanAssets == bank.depositLiabilities + bank.equity) }
        try SnapshotValidator.validate(SimulationSnapshot(state: s))
    }
    @Test func zeroFundsAndBankruptFirms() async throws {
        let engine = SimulationEngine()
        _ = try await engine.createWorld(configuration: .init(population: 24, businessCount: 6, initialHouseholdDeposit: 0, initialBusinessDeposit: 0, initialBankFunding: 0, initialTreasuryFunds: 0))
        _ = try await engine.advance(days: 90)
        let s = try await engine.snapshot().state
        #expect(s.ledger.accounts.values.allSatisfy { $0.balance == 0 })
        #expect(s.businesses.allSatisfy { $0.status == .failed })
        #expect(s.households.filter { $0.employment == .employed }.isEmpty)
        #expect(s.currentMetrics.financialStress > 0)
        #expect(s.ledger.reconcile().isBalanced)
        try SnapshotValidator.validate(.init(state: s))
    }
    @Test func defaultWritesOffClaimButPreservesDebtAndMoney() async throws {
        let engine = SimulationEngine()
        _ = try await engine.createWorld(configuration: .init(population: 1, businessCount: 1, bankCount: 1, initialHouseholdDeposit: 0, initialBusinessDeposit: 0, initialBankFunding: 180_000, initialTreasuryFunds: 0))
        var snapshot = try await engine.snapshot()
        let h = snapshot.state.households[0], bank = snapshot.state.banks[0]
        // Deliberately donate the borrower's liquidity to the bank to create an insolvent test fixture.
        snapshot.state.ledger.transfer(from: h.depositAccountID, to: bank.fundingAccountID, amount: 180_000, kind: .grant, day: 0)
        try await engine.restore(snapshot: snapshot)
        _ = try await engine.advance(days: 90)
        let s = try await engine.snapshot().state
        #expect(s.loans[0].defaulted && s.loans[0].missedPayments == 3)
        #expect(s.households[0].defaulted && s.households[0].debt == 180_000)
        #expect(s.banks[0].performingLoanAssets == 0)
        #expect(s.currentMetrics.householdDefaults == 1)
        #expect(s.ledger.reconcile().isBalanced)
    }
    @Test func eventChangesRealEconomyAndAppliesOnce() async throws {
        let baseline = SimulationEngine(), shock = SimulationEngine()
        let config = SimulationConfiguration(population: 120, businessCount: 12)
        var changed = config
        changed.events = [.init(id: "rate", day: 1, kind: .interestRate(basisPoints: 3_000)), .init(id: "shock", day: 1, kind: .confidenceShock(basisPoints: -5_000)), .init(id: "closure", day: 1, kind: .businessClosure(id: "business-0"))]
        _ = try await baseline.createWorld(configuration: config); _ = try await shock.createWorld(configuration: changed)
        _ = try await baseline.advance(days: 30); _ = try await shock.advance(days: 30)
        let a = try await baseline.snapshot().state, b = try await shock.snapshot().state
        #expect(a.currentMetrics.consumerSpending != b.currentMetrics.consumerSpending)
        #expect(a.households != b.households)
        #expect(b.businesses[0].status == .failed && b.businesses[0].employees.isEmpty)
        #expect(b.appliedEventIDs.count == 3)
        #expect(b.centralBank.annualRateBasisPoints == 3_000)
        #expect(b.ledger.reconcile().isBalanced)
    }
    @Test func rejectsInvalidReferencesAndLoanSchedules() async throws {
        let engine = SimulationEngine()
        _ = try await engine.createWorld(configuration: .init(population: 12, businessCount: 6))
        let baseline = try await engine.snapshot()
        var missing = baseline
        missing.state.households[1].employerID = "missing"
        #expect(throws: SimulationError.self) { try SnapshotValidator.validate(missing) }
        var loan = baseline
        loan.state.loans[0].nextPaymentDay = -1
        #expect(throws: SimulationError.self) { try SnapshotValidator.validate(loan) }
        do { try await engine.restore(snapshot: missing); Issue.record("Invalid snapshot accepted") } catch {}
        #expect(try await engine.snapshot() == baseline)
    }
    @Test func missingEventIDsAreHandled() async throws {
        let engine = SimulationEngine()
        _ = try await engine.createWorld(configuration: .init(population: 0, businessCount: 1, events: [.init(id: "grant", day: 1, kind: .treasuryGrant(householdID: "missing", amount: 50)), .init(id: "close", day: 1, kind: .businessClosure(id: "missing"))]))
        _ = try await engine.advanceOneDay()
        let s = try await engine.snapshot().state
        #expect(s.appliedEventIDs.count == 2)
        #expect(s.journal.contains { $0.message.contains("missing household") })
        #expect(s.currentMetrics.unemploymentPercentage == 0)
        #expect(s.currentMetrics.averageConfidence == 0)
    }
    @Test func pauseResumeAndCancelledBatch() async throws {
        let engine = SimulationEngine()
        _ = try await engine.createWorld(configuration: .init(population: 60, businessCount: 6))
        _ = try await engine.advance(days: 2)
        await engine.pause()
        let pausedDay = try await engine.metrics().day
        for _ in 0..<5 { await Task.yield() }
        #expect(try await engine.metrics().day == pausedDay)
        _ = try await engine.advanceOneDay()
        #expect(try await engine.metrics().day == pausedDay + 1)
        let batch = Task { try await engine.advance(days: 10_000) }
        for _ in 0..<10 { await Task.yield() }
        batch.cancel(); await engine.pause()
        _ = try await batch.value
        let stopped = try await engine.metrics().day
        #expect(stopped < 10_003)
        _ = try await engine.advance(days: 2)
        #expect(try await engine.metrics().day == stopped + 2)
    }
    @Test func invalidConfigurationAndUninitializedEngine() async throws {
        #expect(throws: SimulationError.self) { try WorldGenerator.create(configuration: .init(population: -1)) }
        #expect(throws: SimulationError.self) { try WorldGenerator.create(configuration: .init(bankCount: 0)) }
        #expect(throws: SimulationError.self) { try WorldGenerator.create(configuration: .init(initialHouseholdDeposit: -1)) }
        let engine = SimulationEngine()
        do { _ = try await engine.advanceOneDay(); Issue.record("Advanced without a world") } catch { #expect(error as? SimulationError == .noWorld) }
        do { _ = try await engine.advance(days: -1); Issue.record("Accepted negative days") } catch { #expect(error as? SimulationError == .invalidDayCount) }
    }
}
