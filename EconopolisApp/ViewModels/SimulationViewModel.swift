import EconopolisCore
import Foundation
import Observation
import UIKit

@MainActor @Observable
final class SimulationViewModel {
  private(set) var branches: BranchUpdate?
  private(set) var isPlaying = false
  private(set) var isBusy = true
  private(set) var error: String?
  private(set) var persistenceMessage = "Saved on pause and every 15 days"
  var preferences = AppPreferences()
  private(set) var cityA: CityPresentationSnapshot?
  private(set) var cityB: CityPresentationSnapshot?
  private(set) var demoStage = 0
  @ObservationIgnored private let projector = CityProjectionService()
  var city: CityPresentationSnapshot? { world == .a ? cityA : cityB }
  var world: WorldBranch = .a
  var daysPerSecond = 1.0
  var use2D = false
  var selectedEntity: String?
  @ObservationIgnored private let session = BranchSession()
  @ObservationIgnored private var task: Task<Void, Never>?
  @ObservationIgnored private var store: SessionStore?
  @ObservationIgnored private var revision: UInt64 = 0
  @ObservationIgnored private var resumeOnActive = false
  @ObservationIgnored private var initialized = false
  @ObservationIgnored private var worldReady = false
  @ObservationIgnored private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private enum Command {
    case initialize, play, pause, step
    case reset(Bool)
    case seek(Int)
    case event(EventKind)
    case save
    case demo(Int)
    case crisis(CrisisPlan)
    case policy(PolicyPlan)
    case join(PlayerProfile)
  }

  var update: SimulationUpdate? { world == .a ? branches?.a : branches?.b }
  var entities: WorldEntities? { world == .a ? branches?.entitiesA : branches?.entitiesB }
  var otherEntities: WorldEntities? { world == .a ? branches?.entitiesB : branches?.entitiesA }
  var synchronized: Bool { branches?.a.metrics.day == branches?.b.metrics.day }
  func exportReports() async throws -> [URL] {
    guard let branches else { throw SimulationError.noWorld }
    let token = revision
    let configuration = try await session.configuration()
    guard revision == token, !isPlaying, !isBusy else { throw CancellationError() }
    return try await ReportExporter().write(branches: branches, configuration: configuration)
  }
  func initialize(store: SessionStore? = nil) {
    guard !initialized else { return }
    initialized = true
    self.store = store
    submit(.initialize)
  }
  func play() {
    guard !isPlaying, update != nil, synchronized else { return }
    submit(.play)
  }
  func pause() { submit(.pause) }
  func step() {
    guard synchronized else { return }
    submit(.step)
  }
  func reset(newSeed: Bool = false) { submit(.reset(newSeed)) }
  func join(_ profile: PlayerProfile) { submit(.join(profile)) }
  func seek(_ day: Int) { submit(.seek(day)) }
  func intervene(_ event: EventKind) {
    world = .b
    submit(.event(event))
  }
  func startDemo() { submit(.demo(0)) }
  func nextDemo() { submit(.demo(demoStage)) }
  func schedule(_ plan: CrisisPlan) { submit(.crisis(plan)) }
  func apply(_ policy: PolicyPlan) {
    world = .b
    submit(.policy(policy))
  }
  func evidence(id: String) async throws -> EntityEvidence {
    try await session.evidence(id: id, branch: world)
  }
  func background() {
    resumeOnActive = isPlaying || resumeOnActive
    if backgroundTask == .invalid {
      backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Save economic session") {
        [weak self] in
        Task { @MainActor in
          self?.task?.cancel()
          self?.endBackgroundTask()
        }
      }
    }
    submit(.save)
  }
  func inactive() {
    resumeOnActive = isPlaying || resumeOnActive
    if isPlaying { submit(.pause) }
  }
  func foreground() {
    endBackgroundTask()
    if resumeOnActive {
      resumeOnActive = false
      play()
    }
  }
  func memoryWarning() {
    use2D = true
    submit(.save)
  }
  private func endBackgroundTask() {
    if backgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTask)
      backgroundTask = .invalid
    }
  }
  private func save() async throws {
    guard let store else { return }
    let data = try await session.encode()
    try store.save(data: data, world: world.rawValue)
    persistenceMessage = "Saved locally · \(data.count / 1_024) KB"
  }
  private func publishDemo(_ update: BranchUpdate, token: UInt64) async {
    let scenes = await projector.project(update)
    guard revision == token, !Task.isCancelled else { return }
    branches = update
    cityA = scenes.0
    cityB = scenes.1
  }
  private func refresh(token: UInt64) async throws {

    let result = try await session.update()
    let scenes = await projector.project(result)
    let stage = await session.demoProgress()
    if revision == token && !Task.isCancelled {
      branches = result
      cityA = scenes.0
      cityB = scenes.1
      demoStage = stage
    }
  }
  private func submit(_ command: Command) {
    revision &+= 1
    let token = revision
    let previous = task
    previous?.cancel()
    isPlaying = false
    isBusy = true
    error = nil
    task = Task { [weak self] in
      await previous?.value
      guard let self, !Task.isCancelled, self.revision == token else { return }
      await self.session.pause()
      defer {
        if self.revision == token {
          self.isBusy = false
          self.isPlaying = false
          self.endBackgroundTask()
        }
      }
      do {
        if !self.worldReady {
          let resetting: Bool
          if case .reset = command { resetting = true } else { resetting = false }
          if !resetting, let saved = try self.store?.load() {
            try await self.session.restore(data: saved.archive)
            self.world = WorldBranch(rawValue: saved.selectedWorld) ?? .a
          } else {
            try await self.session.create()
          }
          self.worldReady = true
        }
        switch command {
        case .initialize: break
        case .join(let profile):
          var configuration = SimulationConfiguration(
            seed: self.update?.seed ?? 2_026, population: 1_001)
          configuration.player = profile
          try await self.session.create(configuration: configuration)
          self.world = .a
        case .demo(let stage):
          switch stage {
          case 0:
            try await self.session.prepareDemo()
            self.world = .a
          case 1:
            self.world = .a
            try await self.session.runDemoCrisis { [weak self] update in
              await self?.publishDemo(update, token: token)
            }
          case 2:
            try await self.session.rewindDemo()
            self.world = .b
          case 3:
            self.world = .b
            try await self.session.rescueDemo { [weak self] update in
              await self?.publishDemo(update, token: token)
            }
          default:
            try await self.session.prepareDemo()
            self.world = .a
          }
          self.preferences.feedback()
        case .crisis(let plan): try await self.session.scheduleCrisis(plan)
        case .policy(let policy): try await self.session.applyPolicy(policy)

        case .reset(let newSeed):
          // Explicit user regeneration is the only source of nondeterministic seeds.
          if self.update == nil {
            try await self.session.create()
          } else {
            try await self.session.reset(seed: newSeed ? UInt64.random(in: 0...UInt64.max) : nil)
          }
        case .step: try await self.session.step()
        case .pause, .save: break
        case .seek(let day): try await self.session.seek(day: day)
        case .event(let kind): try await self.session.intervene(kind)
        case .play:
          self.isPlaying = true
          self.isBusy = false
          var publication = ContinuousClock.now - .seconds(1)
          var ticks = 0
          while !Task.isCancelled && self.revision == token {
            try await self.session.step()
            ticks += 1
            guard self.revision == token, !Task.isCancelled else { return }
            if ContinuousClock.now - publication >= .milliseconds(250) {
              try await self.refresh(token: token)
              publication = .now
            }
            if ticks % 15 == 0 { try await self.save() }
            try await Task.sleep(for: .seconds(1 / max(0.25, self.daysPerSecond)))
          }
          return
        }
        guard self.revision == token, !Task.isCancelled else { return }
        try await self.refresh(token: token)
        if self.revision == token { try await self.save() }
      } catch is CancellationError {} catch {
        if self.revision == token { self.error = String(describing: error) }
      }
    }
  }
}
