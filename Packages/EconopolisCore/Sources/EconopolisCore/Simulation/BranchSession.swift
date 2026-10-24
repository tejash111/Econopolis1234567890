import Foundation

public enum WorldBranch: String, Codable, Sendable, CaseIterable, Identifiable {
  case a = "World A"
  case b = "World B"
  public var id: String { rawValue }
}
public struct CitizenSummary: Sendable, Identifiable {
  public let bankID: String
  public let income: Money
  public let cash: Money
  public let id: EntityID
  public let name: String
  public let archetype: String
  public let districtID: EntityID
  public let employerID: EntityID?
  public let employment: EmploymentStatus
  public let balance: Money
  public let debt: Money
  public let confidence: Int
  public let stress: Int
}
public struct WorldEntities: Sendable {
  public let accountOwners: [String: String]
  public let citizens: [CitizenSummary]
  public let businesses: [Business]
}
public struct BranchUpdate: Sendable {
  public let a: SimulationUpdate
  public let b: SimulationUpdate
  public let entitiesA: WorldEntities
  public let entitiesB: WorldEntities
  public let furthestDay: Int
}
public struct SessionArchive: Codable, Sendable {
  public var baseline: SimulationSnapshot? = nil
  public var recordedFuture: SimulationSnapshot? = nil
  public var demoStage: Int? = nil
  public let version: Int
  public let a: SimulationSnapshot
  public let b: SimulationSnapshot
  public let furthestDay: Int
}

/// UI commands are serialized by the presentation owner. Each branch has its own actor and RNG.
public actor BranchSession {
  private let a = SimulationEngine()
  private let b = SimulationEngine()
  private var furthestDay = 0
  private var baseline: SimulationSnapshot?
  private var recordedFuture: SimulationSnapshot?
  private var demoStage = 0
  public init() {}
  public func create(configuration: SimulationConfiguration = .init()) async throws {
    _ = try await a.createWorld(configuration: configuration)
    _ = try await b.createWorld(configuration: configuration)
    furthestDay = 0
    baseline = nil
    recordedFuture = nil
    demoStage = 0
  }
  public func step() async throws {
    try Task.checkCancellation()
    // Complete the pair even when cancellation arrives during this atomic logical day.
    _ = try await a.advanceOneDay()
    _ = try await b.advanceOneDay()
    furthestDay = max(furthestDay, try await a.metrics().day)
  }
  public func pause() async {
    await a.pause()
    await b.pause()
  }
  public func reset(seed: UInt64? = nil) async throws {
    var c = try await a.snapshot().state.configuration
    if let seed { c.seed = seed }
    try await create(configuration: c)
  }
  public func intervene(_ kind: EventKind) async throws {
    let day = try await b.metrics().day
    let count = try await b.snapshot().state.configuration.events.count
    try await b.schedule(
      event: EconomicEvent(id: "intervention-\(day)-\(count)", day: day + 1, kind: kind))
  }
  /// Replays the saved seed and scheduled commands. No per-day snapshot cache on memory-constrained phones.
  public func seek(day: Int) async throws {
    guard (0...furthestDay).contains(day) else { throw SimulationError.invalidDayCount }
    let ca = try await a.snapshot().state.configuration
    let cb = try await b.snapshot().state.configuration
    _ = try await a.createWorld(configuration: ca)
    _ = try await b.createWorld(configuration: cb)
    // Never leave unequal branch days if the caller cancels midway through a replay.
    for _ in 0..<day {
      if Task.isCancelled { break }
      _ = try await a.advanceOneDay()
      _ = try await b.advanceOneDay()
      await Task.yield()
    }
  }
  public func update() async throws -> BranchUpdate {
    BranchUpdate(
      a: try await a.update(), b: try await b.update(), entitiesA: try await a.entities(),
      entitiesB: try await b.entities(), furthestDay: furthestDay)
  }
  public func evidence(id: String, branch: WorldBranch) async throws -> EntityEvidence {
    try await (branch == .a ? a : b).evidence(id: id)
  }
  public func scheduleCrisis(_ plan: CrisisPlan, branch: WorldBranch? = nil) async throws {
    try plan.validate()
    let event = EconomicEvent(id: plan.id, day: plan.startDay, kind: .crisis(plan))
    if branch != .b { try await a.validateEvent(event) }
    if branch != .a { try await b.validateEvent(event) }
    try await a.enableComparableRandomness(from: plan.startDay)
    try await b.enableComparableRandomness(from: plan.startDay)
    if branch != .b {
      try await a.schedule(event: .init(id: plan.id, day: plan.startDay, kind: .crisis(plan)))
    }
    if branch != .a {
      try await b.schedule(event: .init(id: plan.id, day: plan.startDay, kind: .crisis(plan)))
    }
  }
  public func applyPolicy(_ plan: PolicyPlan) async throws {
    try plan.validate()
    try await b.validateEvent(.init(id: plan.id, day: plan.day, kind: .policy(plan)))
    try await a.enableComparableRandomness(from: plan.day)
    try await b.enableComparableRandomness(from: plan.day)
    try await b.schedule(event: .init(id: plan.id, day: plan.day, kind: .policy(plan)))
  }
  public func prepareDemo() async throws {
    try await create(configuration: .init(seed: 2_026))
    for _ in 0..<7 { try await step() }
    baseline = try await a.snapshot()
    try await b.restore(snapshot: baseline!)
    demoStage = 1
  }
  public func runDemoCrisis(progress: (@Sendable (BranchUpdate) async -> Void)? = nil) async throws
  {
    guard demoStage == 1, let baseline else { throw SimulationError.invalidConfiguration }
    try await a.restore(snapshot: baseline)
    try await b.restore(snapshot: baseline)
    let bank = baseline.state.banks.max { $0.depositLiabilities < $1.depositLiabilities }!
    let plan = CrisisPlan(
      id: "the-great-bank-run", kind: .bankRun, targetID: bank.id, severity: 9_000,
      startDay: baseline.state.day + 1, duration: 35)
    try await scheduleCrisis(plan)
    for index in 0..<28 {
      try await step()
      if index % 4 == 3, let progress { await progress(try await update()) }
      await Task.yield()
    }
    recordedFuture = try await a.snapshot()
    demoStage = 2
  }
  public func rewindDemo() async throws {
    guard let baseline, demoStage >= 2 else { throw SimulationError.invalidConfiguration }
    if let recordedFuture { try await a.restore(snapshot: recordedFuture) }
    try await b.restore(snapshot: baseline)
    demoStage = 3
  }
  public func rescueDemo(progress: (@Sendable (BranchUpdate) async -> Void)? = nil) async throws {
    guard let baseline, demoStage == 3 else { throw SimulationError.invalidConfiguration }
    if let recordedFuture { try await a.restore(snapshot: recordedFuture) }
    try await b.restore(snapshot: baseline)
    let source = try await a.snapshot()
    guard
      let event = source.state.configuration.events.first(where: { $0.id == "the-great-bank-run" }),
      case .crisis(let crisis) = event.kind
    else { throw SimulationError.invalidConfiguration }
    try await b.schedule(event: event)
    let bank = baseline.state.banks.first { $0.id == crisis.targetID }!
    let policy = PolicyPlan(
      id: "demo-emergency-liquidity", kind: .liquidity, targetID: bank.id,
      amount: bank.depositLiabilities / 2, day: crisis.startDay, rateBasisPoints: 400)
    try await applyPolicy(policy)
    let days = source.state.day - baseline.state.day
    for index in 0..<days {
      try Task.checkCancellation()
      _ = try await b.advanceOneDay()
      if index % 4 == 3, let progress { await progress(try await update()) }
      await Task.yield()
    }
    demoStage = 4
  }
  public func demoProgress() -> Int { demoStage }
  public func configuration() async throws -> SimulationConfiguration {
    try await a.snapshot().state.configuration
  }
  public func encode() async throws -> Data {
    var archive = SessionArchive(
      version: 1, a: try await a.snapshot(), b: try await b.snapshot(), furthestDay: furthestDay)
    archive.baseline = baseline
    archive.recordedFuture = recordedFuture
    archive.demoStage = demoStage
    return try JSONEncoder().encode(archive)
  }
  public func restore(data: Data) async throws {
    let archive = try JSONDecoder().decode(SessionArchive.self, from: data)
    guard archive.version == 1,
      archive.a.state.day == archive.b.state.day || archive.baseline != nil,
      archive.a.state.configuration.seed == archive.b.state.configuration.seed,
      archive.furthestDay >= archive.a.state.day
    else { throw SimulationError.invalidSnapshot("Branch archive dimensions") }
    try SnapshotValidator.validate(archive.a)
    try SnapshotValidator.validate(archive.b)
    if let checkpoint = archive.baseline { try SnapshotValidator.validate(checkpoint) }
    if let checkpoint = archive.recordedFuture { try SnapshotValidator.validate(checkpoint) }
    try await a.restore(snapshot: archive.a)
    try await b.restore(snapshot: archive.b)
    furthestDay = archive.furthestDay
    baseline = archive.baseline
    recordedFuture = archive.recordedFuture
    demoStage = archive.demoStage ?? 0
  }
}
