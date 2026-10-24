import Foundation

public actor SimulationEngine {
    private var state: SimulationState?
    private var paused = true
    public init() {}
    @discardableResult public func createWorld(configuration: SimulationConfiguration = .init()) throws -> SimulationUpdate {
        let world = try WorldGenerator.create(configuration: configuration)
        generation &+= 1
        state = world; paused = true
        return try update()
    }
    @discardableResult public func advanceOneDay() throws -> SimulationUpdate {
        guard var world = state else { throw SimulationError.noWorld }
        // Move ownership out to avoid copying the growing journal on every tick.
        state = nil
        EconomicKernel.advance(&world)
        state = world
        return try update()
    }
    /// Batch operation yields between days, allowing pause/reset to cancel it through generation ownership.
    @discardableResult public func advance(days: Int) async throws -> SimulationUpdate {
        guard (0...10_000).contains(days) else { throw SimulationError.invalidDayCount }
        guard state != nil else { throw SimulationError.noWorld }
        generation &+= 1
        let token = generation
        paused = false
        for _ in 0..<days {
            if paused || generation != token || Task.isCancelled { break }
            _ = try advanceOneDay()
            await Task.yield()
        }
        if generation == token { paused = true }
        return try update()
    }
    public func pause() { paused = true; generation &+= 1 }
    private var generation: UInt64 = 0
    @discardableResult public func reset(seed: UInt64? = nil) throws -> SimulationUpdate {
        guard var configuration = state?.configuration else { throw SimulationError.noWorld }
        if let seed { configuration.seed = seed }
        generation &+= 1
        return try createWorld(configuration: configuration)
    }
    public func snapshot() throws -> SimulationSnapshot {
        guard let state else { throw SimulationError.noWorld }
        return SimulationSnapshot(state: state)
    }
    public func restore(snapshot: SimulationSnapshot) throws {
        try SnapshotValidator.validate(snapshot)
        var restored = snapshot.state
        restored.recalculate()
        state = restored; paused = true; generation &+= 1
    }
    public func metrics() throws -> EconomyMetrics { guard let state else { throw SimulationError.noWorld }; return state.currentMetrics }
    public func enableComparableRandomness(from day: Int) throws {
        guard state != nil, day > 0 else { throw SimulationError.noWorld }
        state!.configuration.stableRandomFromDay = min(state!.configuration.stableRandomFromDay ?? day, day)
    }
    public func validateEvent(_ event: EconomicEvent) throws {
        guard let state else { throw SimulationError.noWorld }
        guard event.day > state.day, !state.configuration.events.contains(where: { $0.id == event.id }) else { throw SimulationError.invalidConfiguration }
switch event.kind {
case .crisis(let plan):
    try plan.validate()
    guard plan.startDay == event.day else { throw SimulationError.invalidConfiguration }
    if plan.kind == .bankRun { guard state.banks.contains(where: { $0.id == plan.targetID }) else { throw SimulationError.invalidConfiguration } }
    if let target = plan.targetID, plan.kind != .bankRun { guard state.banks.contains(where: { $0.id == target }) || state.districts.contains(where: { $0.id == target }) || Industry.allCases.contains(where: { $0.rawValue == target }) else { throw SimulationError.invalidConfiguration } }
case .policy(let plan):
    try plan.validate()
    guard plan.day == event.day else { throw SimulationError.invalidConfiguration }
    if plan.kind == .liquidity { guard state.banks.contains(where: { $0.id == plan.targetID }) else { throw SimulationError.invalidConfiguration } }
default: break
}
        var configuration = state.configuration
        configuration.events.append(event)
        try configuration.validate()
    }
    public func schedule(event: EconomicEvent) throws {
        try validateEvent(event)
        self.state!.configuration.events.append(event)
    }
    public func evidence(id: String) throws -> EntityEvidence { guard let state else { throw SimulationError.noWorld }; return PresentationQueries.evidence(id: id, state: state) }
    public func entities() throws -> WorldEntities {
        guard let s = state else { throw SimulationError.noWorld }
        return WorldEntities(accountOwners: s.ledger.accounts.mapValues(\.ownerID), citizens: s.households.map { h in
            CitizenSummary(bankID: h.bankID, income: h.monthlyIncome, cash: h.cashBalance, id: h.id, name: h.name, archetype: s.archetypes[h.archetypeID].name, districtID: h.districtID, employerID: h.employerID, employment: h.employment, balance: h.depositBalance, debt: h.debt, confidence: h.confidence, stress: h.financialStress)
        }, businesses: s.businesses)
    }
    public func update() throws -> SimulationUpdate {
        guard let s = state else { throw SimulationError.noWorld }
        return SimulationUpdate(playerID: s.configuration.player == nil ? nil : s.households.last?.id, crisis: s.crisis, seed: s.configuration.seed, metrics: s.currentMetrics, banks: s.banks, districts: s.districts, recentTransactions: Array(s.ledger.settledTransactions.suffix(40).reversed()), history: Array(s.history.suffix(365)), rejectedCount: s.ledger.rejectedTransactions.count, treasury: s.treasury, centralBank: s.centralBank, scheduledEvents: s.configuration.events.filter { $0.day > s.day })
    }
}
