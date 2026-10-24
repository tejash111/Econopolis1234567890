import Foundation

public struct SimulationState: Codable, Sendable, Equatable {
    public var configuration: SimulationConfiguration
    public var day: Int
    public var random: SplitMix64
    public var archetypes: [HouseholdArchetype]
    public var households: [Household]
    public var businesses: [Business]
    public var banks: [Bank]
    public var districts: [District]
    public var treasury: Treasury
    public var centralBank: CentralBank
    public var loans: [Loan]
    public var ledger: Ledger
    public var journal: [JournalEvent]
    public var appliedEventIDs: [EntityID]
    public var currentMetrics: EconomyMetrics
    public var history: [EconomyMetrics]
    public var archetypeConfidence: [Int]
    public var crisis: CrisisState? = nil

    public mutating func recalculate() {
        var debt: [EntityID: Money] = [:], repayments: [EntityID: Money] = [:]
        for loan in loans where !loan.defaulted && loan.outstandingPrincipal > 0 {
            debt[loan.borrowerID, default: 0] += loan.outstandingPrincipal
            repayments[loan.borrowerID, default: 0] += min(loan.installmentPrincipal, loan.outstandingPrincipal)
        }
        for i in households.indices {
            households[i].depositBalance = ledger.balance(households[i].depositAccountID)
            households[i].cashBalance = ledger.balance(households[i].cashAccountID)
            // Defaulted debt remains an obligation, even though it is written off as a bank asset.
            households[i].debt = loans.filter { $0.borrowerID == households[i].id }.reduce(0) { $0 + $1.outstandingPrincipal }
            households[i].scheduledRepayment = repayments[households[i].id, default: 0]
        }
        for i in businesses.indices {
            businesses[i].operatingBalance = ledger.balance(businesses[i].accountID)
            businesses[i].creditExposure = debt[businesses[i].id, default: 0]
            businesses[i].creditExposure += crisis?.publicLoans.filter { !$0.centralBank && $0.borrowerID == businesses[i].id }.reduce(Money(0)) { $0 + $1.outstanding } ?? 0
            businesses[i].profit = businesses[i].revenue - businesses[i].expenses
            businesses[i].payrollObligation = households.filter { $0.employerID == businesses[i].id && $0.employment == .employed }.reduce(0) { $0 + $1.monthlyIncome }
        }
        for i in banks.indices {
            let id = banks[i].id
            let deposits = ledger.accounts.values.filter { $0.bankID == id && $0.kind == .deposit }.reduce(Money(0)) { $0 + $1.balance }
            let available = ledger.balance(banks[i].fundingAccountID)
            let claims = loans.filter { $0.bankID == id && !$0.defaulted }.reduce(Money(0)) { $0 + $1.outstandingPrincipal }
            banks[i].depositLiabilities = deposits
            banks[i].reserves = deposits + available
            banks[i].performingLoanAssets = claims
            let publicDebt = crisis?.publicLoans.filter { $0.centralBank && $0.borrowerID == id }.reduce(Money(0)) { $0 + $1.outstanding } ?? 0
            banks[i].equity = available + claims - publicDebt
            banks[i].liquidityCoverageBasisPoints = deposits == 0 ? 10_000 : Int(min(100_000, (deposits + available) * 10_000 / deposits))
            // Funding pressure is distinct from reserve/deposit coverage in this fully backed model.
            let liquidityStress = configuration.initialBankFunding == 0 ? 10_000 : max(0, 10_000 - Int(available * 10_000 / configuration.initialBankFunding))
            let bad = loans.filter { $0.bankID == id && $0.defaulted }.reduce(Money(0)) { $0 + $1.outstandingPrincipal }
            banks[i].stress = min(10_000, liquidityStress / 2 + Int(bad * 10_000 / max(1, claims + bad)))
            banks[i].status = banks[i].stress > 7_500 ? .intervened : (banks[i].stress > 4_000 ? .stressed : .normal)
            if let crisis, crisis.plans.contains(where: { $0.kind == .bankRun && $0.targetID == id && $0.isActive(day: day) }) {
                banks[i].stress = max(banks[i].stress, crisis.pressure[id, default: 0])
                banks[i].status = crisis.suspendedBanks.contains(id) ? .intervened : (banks[i].stress > 4_000 ? .stressed : .normal)
            }
        }
        treasury.funds = ledger.balance(treasury.accountID)
        let daily = ledger.settledTransactions.reversed().prefix { $0.day == day }
        var m = EconomyMetrics()
        m.day = day; m.population = households.count
        m.employed = households.filter { $0.employment == .employed }.count
        m.laborForce = households.filter { $0.employment == .employed || $0.employment == .unemployed }.count
        m.unemploymentPercentage = m.laborForce == 0 ? 0 : Double(m.laborForce - m.employed) * 100 / Double(m.laborForce)
        m.transactionVolume = daily.reduce(0) { $0 + $1.amount }
        let spending = daily.filter { $0.kind == .essential || $0.kind == .discretionary }
        m.consumerSpending = spending.reduce(0) { $0 + $1.amount }
        m.aggregateHouseholdDebt = households.reduce(0) { $0 + $1.debt }
        m.averageConfidence = households.isEmpty ? 0 : Double(households.reduce(0) { $0 + $1.confidence }) / Double(households.count * 100)
        m.activeBusinesses = businesses.filter { $0.status != .failed }.count
        m.failedBusinesses = businesses.count - m.activeBusinesses
        m.householdDefaults = households.filter(\.defaulted).count
        m.bankLiquidityStress = banks.isEmpty ? 0 : Double(banks.reduce(0) { $0 + $1.stress }) / Double(banks.count * 100)
        let householdStress = households.isEmpty ? 0 : Double(households.reduce(0) { $0 + $1.financialStress }) / Double(households.count * 100)
        m.financialStress = min(100, householdStress * 0.6 + m.bankLiquidityStress * 0.2 + m.unemploymentPercentage * 0.2)
        var activity: [EntityID: Money] = [:]
        let businessDistrict = Dictionary(uniqueKeysWithValues: businesses.map { ($0.accountID, $0.districtID) })
        for tx in spending { if let district = businessDistrict[tx.recipient] { activity[district, default: 0] += tx.amount } }
        m.districts = districts.map { d in
            DistrictActivity(id: d.id, population: households.filter { $0.districtID == d.id }.count,
                             employed: households.filter { $0.districtID == d.id && $0.employment == .employed }.count,
                             consumerSpending: activity[d.id, default: 0], activeBusinesses: businesses.filter { $0.districtID == d.id && $0.status != .failed }.count)
        }
        currentMetrics = m
    }
}

public struct SimulationSnapshot: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public var state: SimulationState
    public init(state: SimulationState) { schemaVersion = 1; self.state = state }
    public func write(to url: URL) throws { try JSONEncoder().encode(self).write(to: url, options: .atomic) }
    public static func read(from url: URL) throws -> Self { try JSONDecoder().decode(Self.self, from: Data(contentsOf: url)) }
}

/// UI payload deliberately excludes the full ledger and all household records.
public struct SimulationUpdate: Sendable {
    public let playerID: String?
    public let crisis: CrisisState?
    public let seed: UInt64
    public let metrics: EconomyMetrics
    public let banks: [Bank]
    public let districts: [District]
    public let recentTransactions: [Transaction]
    public let history: [EconomyMetrics]
    public let rejectedCount: Int
    public let treasury: Treasury
    public let centralBank: CentralBank
    public let scheduledEvents: [EconomicEvent]
}
