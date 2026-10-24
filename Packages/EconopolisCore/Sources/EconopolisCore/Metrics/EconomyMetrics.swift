import Foundation

public struct DistrictActivity: Codable, Sendable, Equatable, Identifiable {
    public let id: EntityID
    public let population: Int
    public let employed: Int
    public let consumerSpending: Money
    public let activeBusinesses: Int
}
public struct EconomyMetrics: Codable, Sendable, Equatable {
    public var day: Int = 0
    public var population: Int = 0
    public var employed: Int = 0
    public var laborForce: Int = 0
    public var unemploymentPercentage: Double = 0
    public var transactionVolume: Money = 0
    public var consumerSpending: Money = 0
    public var aggregateHouseholdDebt: Money = 0
    public var averageConfidence: Double = 0
    public var activeBusinesses: Int = 0
    public var failedBusinesses: Int = 0
    public var bankLiquidityStress: Double = 0
    public var householdDefaults: Int = 0
    public var financialStress: Double = 0
    public var districts: [DistrictActivity] = []
    public init() {}
}
