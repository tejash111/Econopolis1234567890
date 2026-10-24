import EconopolisCore
import Foundation
import Testing

@testable import Econopolis

@Suite("Phase 2 presentation", .serialized)
@MainActor
struct Phase2PresentationTests {
  @Test func cityUsesActualEntitiesAndDeterministicLayout() async throws {
    let engine = SimulationEngine()
    let update = try await engine.createWorld()
    let entities = try await engine.entities()
    let a = CityLayout.project(update: update, entities: entities)
    let b = CityLayout.project(update: update, entities: entities)
    #expect(a.lots == b.lots && a.districts.count == 6)
    let ids = Set(a.lots.map(\.id))
    #expect(Set(entities.businesses.map(\.id)).isSubset(of: ids))
    #expect(Set(update.banks.map(\.id)).isSubset(of: ids))
    let residents = a.markers.filter { !$0.work }.flatMap(\.citizenIDs)
    #expect(residents.count == 1_000 && Set(residents) == Set(entities.citizens.map(\.id)))
    #expect(
      a.lots.filter { $0.kind == .apartment }.allSatisfy {
        update.districts.map(\.id).contains($0.selectionID)
      })
    _ = try await engine.reset(seed: 55)
    let other = CityLayout.lots(
      update: try await engine.update(), entities: try await engine.entities())
    #expect(other != a.lots)
  }
  @Test func heatmapsChartsAndFlowsUseRecordedData() async throws {
    let engine = SimulationEngine()
    _ = try await engine.createWorld()
    _ = try await engine.advance(days: 5)
    let update = try await engine.update()
    let entities = try await engine.entities()
    let projection = CityLayout.project(update: update, entities: entities)
    #expect(projection.metrics == update.metrics)
    #expect(
      projection.flows.allSatisfy {
        $0.transaction.settled && $0.transaction.day == update.metrics.day
          && update.recentTransactions.contains($0.transaction)
      })
    for i in projection.districts.indices {
      for mode in HeatmapMode.allCases {
        #expect((0...10_000).contains(projection.heat(mode, district: i)))
      }
    }
    let samples = ChartProjection.samples(history: update.history, metric: .spending, range: 2)
    #expect(
      samples.count == 2 && samples.last?.value == Double(update.metrics.consumerSpending) / 100)
    #expect(samples.map(\.day) == [4, 5])
    #expect(ChartProjection.samples(history: [], metric: .debt, range: 30).isEmpty)
  }
  @Test func directoryFiltersAndProfilesResolveIDs() async throws {
    let engine = SimulationEngine()
    _ = try await engine.createWorld()
    _ = try await engine.advanceOneDay()
    let entities = try await engine.entities()
    let person = try #require(try await engine.entities().citizens.last)
    var filter = CitizenFilter()
    filter.query = person.id
    #expect(filter.apply(entities.citizens).map(\.id) == [person.id])
    filter.query = "no such fictional citizen"
    #expect(filter.apply(entities.citizens).isEmpty)
    filter.query = ""
    filter.district = person.districtID
    filter.archetype = person.archetype
    #expect(
      filter.apply(entities.citizens).allSatisfy {
        $0.districtID == person.districtID && $0.archetype == person.archetype
      })
    let evidence = try await engine.evidence(id: person.id)
    #expect(evidence.household?.monthlyIncome == person.income)
    #expect(evidence.household?.bankID == person.bankID)
    #expect(evidence.transactions.allSatisfy { $0.settled })
    #expect(try await engine.evidence(id: "missing").household == nil)
  }
  @Test func cameraBoundsAndInvalidInputs() {
    var pose = CityCameraPose()
    pose.zoom(1_000)
    #expect(pose.distance == 10)
    pose.zoom(0.00001)
    #expect(pose.distance == 70)
    pose.orbit(x: 100, y: 1_000)
    #expect(pose.pitch == 1.3)
    pose.pan(x: 100_000, z: -100_000)
    #expect(pose.target.x == -16 && pose.target.z == 12)
    let copy = pose
    pose.zoom(.nan)
    #expect(pose == copy)
  }
  @Test func playbackPublishesMatchingCityAndReset() async throws {
    let model = SimulationViewModel()
    model.initialize()
    try await idle(model)
    #expect(model.city?.day == 0 && model.city?.lots.count ?? 0 >= 86)
    model.step()
    try await idle(model)
    #expect(model.city?.metrics == model.update?.metrics)
    model.reset(newSeed: true)
    try await idle(model)
    #expect(model.city?.seed == model.update?.seed && model.city?.day == 0)
  }
  private func idle(_ model: SimulationViewModel) async throws {
    let limit = ContinuousClock.now + .seconds(30)
    while model.isBusy && ContinuousClock.now < limit {
      try await Task.sleep(for: .milliseconds(25))
    }
    #expect(!model.isBusy && model.error == nil)
  }
}
