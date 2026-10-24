import EconopolisCore
import Foundation
import Testing

@testable import Econopolis

@Suite("iPhone simulation controls", .serialized)
@MainActor
struct PlaybackTests {
  private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(20)
    while !condition() && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(20))
    }
    #expect(condition())
  }
  @Test func launchStepPlayPauseResetAndRegenerate() async throws {
    let model = SimulationViewModel()
    model.initialize()
    try await waitUntil { !model.isBusy }
    #expect(model.error == nil)
    #expect(model.update?.metrics.population == 1_000)
    #expect(model.update?.metrics.day == 0)
    let baseline = model.update?.metrics
    let seed = model.update?.seed
    model.step()
    try await waitUntil { !model.isBusy }
    #expect(model.update?.metrics.day == 1)
    #expect((model.update?.metrics.consumerSpending ?? 0) > 0)
    model.daysPerSecond = 10
    model.play()
    model.play()
    try await waitUntil { (model.update?.metrics.day ?? 0) >= 3 }
    model.pause()
    try await waitUntil { !model.isBusy }
    let day = model.update?.metrics.day
    try await Task.sleep(for: .milliseconds(250))
    #expect(model.update?.metrics.day == day)
    model.play()
    try await waitUntil { (model.update?.metrics.day ?? 0) > (day ?? 0) }
    model.reset()
    try await waitUntil { !model.isBusy }
    #expect(model.update?.metrics == baseline)
    #expect(model.update?.seed == seed)
    try await Task.sleep(for: .milliseconds(250))
    #expect(model.update?.metrics.day == 0)
    model.play()
    model.reset(newSeed: true)
    try await waitUntil { !model.isBusy }
    #expect(model.update?.seed != seed)
    #expect(model.update?.metrics.day == 0)
    #expect(!model.isPlaying && model.error == nil)
  }
  @Test func rapidCommandsHaveOneOwner() async throws {
    let model = SimulationViewModel()
    model.initialize()
    try await waitUntil { !model.isBusy }
    for _ in 0..<20 {
      model.play()
      model.pause()
      model.step()
      model.reset()
    }
    try await waitUntil { !model.isBusy }
    #expect(model.update?.metrics.day == 0)
    #expect(model.error == nil && !model.isPlaying)
  }
}

@Suite("iPhone lifecycle and local storage", .serialized)
@MainActor
struct LifecycleTests {
  private func idle(_ model: SimulationViewModel) async throws {
    let deadline = ContinuousClock.now + .seconds(30)
    while model.isBusy && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(25))
    }
    #expect(!model.isBusy && model.error == nil)
  }
  @Test func autosaveRestoreAndBackgroundResume() async throws {
    let store = try SessionStore(inMemory: true)
    let model = SimulationViewModel()
    model.initialize(store: store)
    try await idle(model)
    model.step()
    try await idle(model)
    model.world = .b
    model.background()
    try await idle(model)
    #expect(try store.load() != nil)
    let restored = SimulationViewModel()
    restored.initialize(store: store)
    try await idle(restored)
    #expect(restored.world == .b && restored.update?.metrics.day == 1)
    #expect(restored.update?.metrics == model.update?.metrics)
    model.daysPerSecond = 10
    model.play()
    try await Task.sleep(for: .milliseconds(300))
    model.inactive()
    try await idle(model)
    let paused = model.update?.metrics.day
    try await Task.sleep(for: .milliseconds(200))
    #expect(model.update?.metrics.day == paused)
    model.foreground()
    try await Task.sleep(for: .milliseconds(300))
    model.pause()
    try await idle(model)
    #expect((model.update?.metrics.day ?? 0) > (paused ?? 0))
    model.memoryWarning()
    try await idle(model)
    #expect(model.use2D && !model.isPlaying)
  }
  @Test func mobileBranchControls() async throws {
    let model = SimulationViewModel()
    model.initialize()
    try await idle(model)
    model.intervene(.confidenceShock(basisPoints: -5_000))
    try await idle(model)
    #expect(model.world == .b && model.branches?.b.scheduledEvents.count == 1)
    model.step()
    try await idle(model)
    #expect(
      model.branches?.a.metrics.consumerSpending != model.branches?.b.metrics.consumerSpending)
    let m = model.update?.metrics
    model.seek(0)
    try await idle(model)
    #expect(model.update?.metrics.day == 0)
    model.seek(1)
    try await idle(model)
    #expect(model.update?.metrics == m)
  }
}

@Suite("Interrupted launch recovery", .serialized)
@MainActor
struct LaunchRecoveryTests {
  @Test func backgroundBeforeInitializationTaskStarts() async throws {
    let store = try SessionStore(inMemory: true)
    let model = SimulationViewModel()
    model.initialize(store: store)
    model.background()
    let deadline = ContinuousClock.now + .seconds(30)
    while model.isBusy && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(25))
    }
    #expect(model.error == nil && model.update?.metrics.population == 1_000)
    #expect(try store.load() != nil)
  }
  @Test func corruptArchiveRequiresExplicitReset() async throws {
    let store = try SessionStore(inMemory: true)
    try store.save(data: Data("invalid JSON".utf8), world: "World A")
    let model = SimulationViewModel()
    model.initialize(store: store)
    for _ in 0..<100 where model.isBusy { try await Task.sleep(for: .milliseconds(20)) }
    #expect(model.error != nil && model.update == nil)
    #expect(try store.load()?.archive == Data("invalid JSON".utf8))
    model.reset()
    let deadline = ContinuousClock.now + .seconds(30)
    while model.isBusy && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(25))
    }
    #expect(model.error == nil && model.update?.metrics.day == 0)
  }
}
