import Foundation

/// All monetary values are integer cents. Ratios use integer basis points (10,000 = 100%).
public typealias Money = Int64
public typealias EntityID = String

public enum EmploymentStatus: String, Codable, Sendable { case employed, unemployed, student, retired }
public enum OperationalStatus: String, Codable, Sendable { case active, distressed, failed }
public enum BankStatus: String, Codable, Sendable { case normal, stressed, intervened }
public enum Industry: String, Codable, Sendable, CaseIterable { case services, technology, manufacturing, retail, logistics, education }

public struct HouseholdArchetype: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let monthlyIncome: Money
    public let essentialDaily: Money
    public let discretionaryDaily: Money
    public let savingPreference: Int
    public let laborStatus: EmploymentStatus
    public let preferredIndustry: Industry
}

public struct Decision: Codable, Sendable, Equatable {
    public let day: Int
    public let spending: Money
    public let confidence: Int
    public let reason: String
}

public struct Household: Codable, Sendable, Equatable, Identifiable {
    public let id: EntityID
    public let name: String
    public let archetypeID: Int
    public let districtID: EntityID
    public var employerID: EntityID?
    public var employment: EmploymentStatus
    public let bankID: EntityID
    public let depositAccountID: EntityID
    public let cashAccountID: EntityID
    public var monthlyIncome: Money
    public let essentialDaily: Money
    public let discretionaryDaily: Money
    public let savingPreference: Int
    public let personalVariation: Int
    public var depositBalance: Money = 0
    public var cashBalance: Money = 0
    public var debt: Money = 0
    public var scheduledRepayment: Money = 0
    public var financialStress: Int = 0
    public var confidence: Int = 7_000
    public var happiness: Int = 7_000
    public var defaulted: Bool = false
    public var decisions: [Decision] = []
}

public struct Business: Codable, Sendable, Equatable, Identifiable {
    public let id: EntityID
    public let name: String
    public let industry: Industry
    public let districtID: EntityID
    public let bankID: EntityID
    public let accountID: EntityID
    public var operatingBalance: Money = 0
    public var revenue: Money = 0
    public var expenses: Money = 0
    public var profit: Money = 0
    public var employees: [EntityID] = []
    public var payrollObligation: Money = 0
    public var creditExposure: Money = 0
    public var status: OperationalStatus = .active
    public var financialHealth: Int = 10_000
    public var stressDays: Int = 0
}

public struct Bank: Codable, Sendable, Equatable, Identifiable {
    public let id: EntityID
    public let name: String
    public let fundingAccountID: EntityID
    public var customers: [EntityID] = []
    public var loanIDs: [EntityID] = []
    public var reserves: Money = 0
    public var depositLiabilities: Money = 0
    public var performingLoanAssets: Money = 0
    public var equity: Money = 0
    public var liquidityCoverageBasisPoints: Int = 10_000
    public var stress: Int = 0
    public var status: BankStatus = .normal
}

public struct District: Codable, Sendable, Equatable, Identifiable {
    public let id: EntityID
    public let name: String
    public let dominantIndustry: Industry
    public let incomeMultiplier: Int
    public let consumptionMultiplier: Int
    public let businessWeight: Int
}

public struct Treasury: Codable, Sendable, Equatable {
    public let id: EntityID
    public let accountID: EntityID
    public var funds: Money = 0
    public var taxCollected: Money = 0
    public var benefitsPaid: Money = 0
}
public struct CentralBank: Codable, Sendable, Equatable {
    public let id: EntityID
    public var annualRateBasisPoints: Int
    public var emergencyFunding: Money = 0
}

public struct Loan: Codable, Sendable, Equatable, Identifiable {
    public let id: EntityID
    public let borrowerID: EntityID
    public let borrowerAccountID: EntityID
    public let bankID: EntityID
    public let originalPrincipal: Money
    public var outstandingPrincipal: Money
    public let annualSpreadBasisPoints: Int
    public let installmentPrincipal: Money
    public var nextPaymentDay: Int
    public let intervalDays: Int
    public let maturityDay: Int
    public var missedPayments: Int = 0
    public var defaulted: Bool = false
    public var interestPaid: Money = 0
}

public enum EventKind: Codable, Sendable, Equatable {
    case crisis(CrisisPlan)
    case policy(PolicyPlan)
    case confidenceShock(basisPoints: Int)
    case interestRate(basisPoints: Int)
    case businessClosure(id: EntityID)
    case treasuryGrant(householdID: EntityID, amount: Money)
}
public struct EconomicEvent: Codable, Sendable, Equatable, Identifiable {
    public let id: EntityID
    public let day: Int
    public let kind: EventKind
    public init(id: EntityID, day: Int, kind: EventKind) { self.id = id; self.day = day; self.kind = kind }
}
public struct JournalEvent: Codable, Sendable, Equatable {
    public let day: Int
    public let entityID: EntityID
    public let message: String
}

public struct SimulationConfiguration: Codable, Sendable, Equatable {
    public var stableRandomFromDay: Int? = nil
    public var player: PlayerProfile? = nil
    public var seed: UInt64
    public var population: Int
    public var businessCount: Int
    public var bankCount: Int
    public var initialHouseholdDeposit: Money
    public var initialBusinessDeposit: Money
    public var initialBankFunding: Money
    public var initialTreasuryFunds: Money
    public var initialPolicyRate: Int
    public var events: [EconomicEvent]
    public init(seed: UInt64 = 2_026, population: Int = 1_000, businessCount: Int = 80, bankCount: Int = 4,
                initialHouseholdDeposit: Money = 400_000, initialBusinessDeposit: Money = 8_000_000,
                initialBankFunding: Money = 30_000_000, initialTreasuryFunds: Money = 300_000_000,
                initialPolicyRate: Int = 400, events: [EconomicEvent] = []) {
        self.seed = seed; self.population = population; self.businessCount = businessCount; self.bankCount = bankCount
        self.initialHouseholdDeposit = initialHouseholdDeposit; self.initialBusinessDeposit = initialBusinessDeposit
        self.initialBankFunding = initialBankFunding; self.initialTreasuryFunds = initialTreasuryFunds
        self.initialPolicyRate = initialPolicyRate; self.events = events
    }
    public func validate() throws {
        try player?.validate()
        if let day = stableRandomFromDay, !(1...1_000_000).contains(day) { throw SimulationError.invalidConfiguration }
        for event in events {
            switch event.kind {
            case .crisis(let plan): try plan.validate(); guard plan.startDay == event.day else { throw SimulationError.invalidConfiguration }
            case .policy(let plan): try plan.validate(); guard plan.day == event.day else { throw SimulationError.invalidConfiguration }
            default: break
            }
        }
        guard (0...10_000).contains(population), (1...500).contains(businessCount), (1...20).contains(bankCount),
              [initialHouseholdDeposit, initialBusinessDeposit, initialBankFunding, initialTreasuryFunds].allSatisfy({ (0...1_000_000_000).contains($0) }),
              (0...10_000).contains(initialPolicyRate), events.allSatisfy({ (1...1_000_000).contains($0.day) }),
              Set(events.map(\.id)).count == events.count else { throw SimulationError.invalidConfiguration }
    }
}
public enum SimulationError: Error, Equatable { case invalidConfiguration, noWorld, invalidSnapshot(String), invalidDayCount }
