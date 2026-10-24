import Foundation

public enum CrisisKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case bankRun = "Bank Run", interestRate = "Interest Rate Shock", layoffs = "Mass Layoffs", recession = "Recession", creditCrunch = "Credit Crunch", paymentOutage = "Payment Outage"
    public var id: String { rawValue }
}
public struct CrisisPlan: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public var kind: CrisisKind
    public var targetID: String?
    public var severity: Int
    public var startDay: Int
    public var duration: Int
    public var rateBasisPoints: Int
    public init(id: String, kind: CrisisKind, targetID: String? = nil, severity: Int = 7_500, startDay: Int, duration: Int = 14, rateBasisPoints: Int = 1_200) {
        self.id = id; self.kind = kind; self.targetID = targetID; self.severity = severity; self.startDay = startDay; self.duration = duration; self.rateBasisPoints = rateBasisPoints
    }
    public func validate() throws {
        guard !id.isEmpty, (1...365).contains(duration), (0...10_000).contains(severity), (1...100_000).contains(startDay), (0...10_000).contains(rateBasisPoints) else { throw SimulationError.invalidConfiguration }
    }
    public func isActive(day: Int) -> Bool { day >= startDay && day < startDay + duration }
}
public enum PolicyKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case liquidity = "Emergency Liquidity", guarantee = "Deposit Guarantee", rate = "Policy Rate", relief = "Household Relief", businessCredit = "Business Credit Facility"
    public var id: String { rawValue }
}
public struct PolicyPlan: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public var kind: PolicyKind
    public var targetID: String?
    public var amount: Money
    public var day: Int
    public var duration: Int
    public var rateBasisPoints: Int
    public init(id: String, kind: PolicyKind, targetID: String? = nil, amount: Money = 100_000_000, day: Int, duration: Int = 30, rateBasisPoints: Int = 400) {
        self.id = id; self.kind = kind; self.targetID = targetID; self.amount = amount; self.day = day; self.duration = duration; self.rateBasisPoints = rateBasisPoints
    }
    public func validate() throws {
        guard (0...1_000_000_000).contains(amount), (1...100_000).contains(day), (1...365).contains(duration), (0...10_000).contains(rateBasisPoints) else { throw SimulationError.invalidConfiguration }
        if [.liquidity, .relief, .businessCredit].contains(kind), amount == 0 { throw SimulationError.invalidConfiguration }
    }
}
public struct CausalRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let day: Int
    public let originID: String
    public let entityID: String
    public let message: String
    public let amount: Money
    public let transactionID: Int?
}
public struct PublicLoan: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let borrowerID: String
    public let accountID: String
    public let centralBank: Bool
    public let original: Money
    public var outstanding: Money
    public let rate: Int
    public var dueDay: Int
    public var missed: Int = 0
}
public struct CrisisState: Codable, Sendable, Equatable {
    public var rateBeforeShocks: Int? = nil
    public var nextRecordID: Int = 0
    public var plans: [CrisisPlan] = []
    public var policies: [PolicyPlan] = []
    public var records: [CausalRecord] = []
    public var publicLoans: [PublicLoan] = []
    public var requestedWithdrawals: Money = 0
    public var settledWithdrawals: Money = 0
    public var unmetWithdrawals: Money = 0
    public var fiscalCost: Money = 0
    public var pressure: [String: Int] = [:]
    public var illiquidDays: [String: Int] = [:]
    public var suspendedBanks: [String] = []
    public init() {}
    public var emergencyClaims: Money { publicLoans.filter(\.centralBank).reduce(0) { $0 + $1.outstanding } }
}
public struct QueuedPayment: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let sender: String
    public let recipient: String
    public let amount: Money
    public let kind: TransactionKind
    public let requestedDay: Int
}
public struct MoneySupplyChange: Codable, Sendable, Equatable {
    public let day: Int
    public let accountID: String
    public let amount: Money
    public let reason: String
}
