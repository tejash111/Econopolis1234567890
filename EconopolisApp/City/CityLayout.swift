import EconopolisCore
import Foundation

struct CityLot: Identifiable, Sendable, Equatable {
  enum Kind: String, Sendable {
    case office, shop, warehouse, factory, university, apartment, bank, civic
  }
  let id: String
  let name: String
  let x: Float
  let z: Float
  let height: Float
  let district: Int
  let kind: Kind
  let stress: Int
  var isBank: Bool { kind == .bank || kind == .civic }
  var failed: Bool { stress >= 10_000 }
  var selectionID: String { kind == .apartment ? "district-\(district)" : id }
}
enum HeatmapMode: String, CaseIterable, Identifiable, Sendable {
  case off = "Standard"
  case activity = "Activity"
  case businessStress = "Business stress"
  case employment = "Employment"
  case banking = "Banking stress"
  var id: String { rawValue }
}
enum GraphicsQuality: String, CaseIterable, Identifiable {
  case low = "Low"
  case balanced = "Balanced"
  case high = "High"
  var id: String { rawValue }
  var markerLimit: Int { self == .low ? 18 : (self == .balanced ? 48 : 96) }
  var flowLimit: Int { self == .low ? 3 : (self == .balanced ? 8 : 14) }
}
struct ActivityMarker: Identifiable, Sendable {
  let id: String
  let district: Int
  let x: Float
  let z: Float
  let citizenIDs: [String]
  let work: Bool
}
struct CityFlow: Identifiable, Sendable {
  let id: Int
  let transaction: Transaction
  let from: SIMD3<Float>
  let to: SIMD3<Float>
}
struct CityPresentationSnapshot: Sendable {
  let branch: WorldBranch
  let seed: UInt64
  let day: Int
  let lots: [CityLot]
  let districts: [District]
  let metrics: EconomyMetrics
  let districtStress: [Int]
  let employmentStress: [Int]
  let bankingStress: [Int]
  let activity: [Money]
  let markers: [ActivityMarker]
  let flows: [CityFlow]
  var identity: String { "\(seed)-\(lots.map(\.id).joined(separator: ","))" }
  func heat(_ mode: HeatmapMode, district: Int) -> Int {
    guard districts.indices.contains(district) else { return 0 }
    switch mode {
    case .off: return 0
    case .businessStress: return districtStress[district]
    case .employment: return employmentStress[district]
    case .banking: return bankingStress[district]
    case .activity:
      let maximum = max(1, activity.max() ?? 1)
      return 10_000 - Int(activity[district] * 10_000 / maximum)
    }
  }
}
enum CityLayout {
  static func center(_ index: Int) -> SIMD3<Float> {
    [Float(index % 3 - 1) * 8.4, 0, Float(index / 3) * 8.2 - 4.1]
  }
  static func lots(update: SimulationUpdate, entities: WorldEntities) -> [CityLot] {
    var random = SplitMix64(seed: update.seed ^ 0xEC00115)
    var slots: [String: Int] = [:]
    var lots: [CityLot] = []
    for business in entities.businesses {
      guard let index = update.districts.firstIndex(where: { $0.id == business.districtID }) else {
        continue
      }
      let slot = slots[business.districtID, default: 0]
      slots[business.districtID] = slot + 1
      let origin = center(index)
      let variation = Float(random.integer(80...120)) / 100
      let kind: CityLot.Kind
      switch business.industry {
      case .technology, .services: kind = .office
      case .manufacturing: kind = .factory
      case .logistics: kind = .warehouse
      case .education: kind = .university
      case .retail: kind = .shop
      }
      let base: Float = index == 0 ? 1.4 : (index == 1 ? 1.05 : 0.45)
      lots.append(
        CityLot(
          id: business.id, name: business.name, x: origin.x + Float(slot % 5) * 1.15 - 2.5,
          z: origin.z + Float(slot / 5) * 1.12 - 2.8,
          height: business.status == .failed
            ? 0.25 : (base + min(1.6, Float(business.employees.count) * 0.05)) * variation,
          district: index, kind: kind,
          stress: business.status == .failed ? 10_000 : 10_000 - business.financialHealth))
    }
    for (i, bank) in update.banks.enumerated() {
      let origin = center(0)
      lots.append(
        CityLot(
          id: bank.id, name: bank.name, x: origin.x + Float(i % 4) * 1.55 - 2.2, z: origin.z + 2.55,
          height: 2.6 + Float(i % 3) * 0.35, district: 0, kind: .bank, stress: bank.stress))
    }
    for (index, district) in update.districts.enumerated() {
      let population = entities.citizens.filter { $0.districtID == district.id }.count
      let origin = center(index)
      for block in 0..<min(4, (population + 59) / 60) {
        lots.append(
          CityLot(
            id: "homes-\(district.id)-\(block)", name: "\(district.name) · residential density",
            x: origin.x + Float(block) * 1.25 - 2.3, z: origin.z + 1.6,
            height: index == 5 ? 1.7 : 0.7, district: index, kind: .apartment, stress: 0))
      }
    }
    lots.append(
      CityLot(
        id: "treasury", name: "Municipal Treasury", x: 0.5, z: 0, height: 1.0, district: 4,
        kind: .civic, stress: 0))
    lots.append(
      CityLot(
        id: "central-bank", name: "Central Bank", x: -1.2, z: 0, height: 1.4, district: 0,
        kind: .civic, stress: 0))
    return lots
  }
  static func project(update: SimulationUpdate, entities: WorldEntities, branch: WorldBranch = .a)
    -> CityPresentationSnapshot
  {
    let lots = lots(update: update, entities: entities)
    var markers: [ActivityMarker] = []
    var stresses: [Int] = []
    var employment: [Int] = []
    var bankStress: [Int] = []
    var activity: [Money] = []
    var random = SplitMix64(seed: update.seed ^ 0xD31517)
    let businesses = Dictionary(uniqueKeysWithValues: entities.businesses.map { ($0.id, $0) })
    for (i, district) in update.districts.enumerated() {
      let residents = entities.citizens.filter { $0.districtID == district.id }
      let firms = entities.businesses.filter { $0.districtID == district.id }
      stresses.append(
        firms.isEmpty ? 0 : firms.reduce(0) { $0 + 10_000 - $1.financialHealth } / firms.count)
      let labor = residents.filter { $0.employment == .employed || $0.employment == .unemployed }
      employment.append(
        labor.isEmpty
          ? 0 : labor.filter { $0.employment == .unemployed }.count * 10_000 / labor.count)
      let banks = update.banks.filter { b in residents.contains { $0.bankID == b.id } }
      bankStress.append(banks.isEmpty ? 0 : banks.reduce(0) { $0 + $1.stress } / banks.count)
      activity.append(
        update.metrics.districts.first { $0.id == district.id }?.consumerSpending ?? 0)
      let origin = center(i)
      for start in stride(from: 0, to: residents.count, by: 25) {
        markers.append(
          ActivityMarker(
            id: "density-\(i)-\(start)", district: i,
            x: origin.x + Float(random.integer(-300...300)) / 100,
            z: origin.z + Float(random.integer(-300...300)) / 100,
            citizenIDs: residents[start..<min(start + 25, residents.count)].map(\.id), work: false))
      }
      let workers = entities.citizens.filter {
        $0.employerID.flatMap { businesses[$0]?.districtID } == district.id
      }
      if !workers.isEmpty {
        markers.append(
          ActivityMarker(
            id: "work-\(i)", district: i, x: origin.x + 3.1, z: origin.z,
            citizenIDs: workers.map(\.id), work: true))
      }
    }
    let positions = Dictionary(
      uniqueKeysWithValues: lots.filter { $0.kind != .apartment }.map {
        ($0.id, SIMD3<Float>($0.x, $0.height + 0.2, $0.z))
      })
    let residents = Dictionary(
      uniqueKeysWithValues: entities.citizens.map { ($0.id, $0.districtID) })
    func position(_ account: String) -> SIMD3<Float>? {
      guard let owner = entities.accountOwners[account] else { return nil }
      if let point = positions[owner] { return point }
      if let home = residents[owner], let i = update.districts.firstIndex(where: { $0.id == home })
      {
        return center(i) + SIMD3<Float>(0, 0.3, 2.7)
      }
      return nil
    }
    let flows = update.recentTransactions.filter { $0.settled && $0.day == update.metrics.day }
      .compactMap { tx -> CityFlow? in
        guard let from = position(tx.sender), let to = position(tx.recipient), from != to else {
          return nil
        }
        return CityFlow(id: tx.id, transaction: tx, from: from, to: to)
      }
    return CityPresentationSnapshot(
      branch: branch, seed: update.seed, day: update.metrics.day, lots: lots,
      districts: update.districts, metrics: update.metrics, districtStress: stresses,
      employmentStress: employment, bankingStress: bankStress, activity: activity, markers: markers,
      flows: flows)
  }
}

actor CityProjectionService {
  func project(_ branches: BranchUpdate) -> (CityPresentationSnapshot, CityPresentationSnapshot) {
    (
      CityLayout.project(update: branches.a, entities: branches.entitiesA, branch: .a),
      CityLayout.project(update: branches.b, entities: branches.entitiesB, branch: .b)
    )
  }
}
