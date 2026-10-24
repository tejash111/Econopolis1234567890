import Foundation

public enum WorldGenerator {
    public static let archetypes: [HouseholdArchetype] = {
        let names = ["Student", "Service worker", "Technology worker", "Industrial worker", "Gig worker", "Business owner", "Retiree", "Executive", "Educator", "Harbor worker", "Retail worker", "Graduate researcher"]
        let incomes: [Money] = [85_000, 240_000, 620_000, 320_000, 200_000, 480_000, 150_000, 950_000, 360_000, 310_000, 220_000, 180_000]
        let essentials: [Money] = [1_800, 3_000, 4_000, 3_200, 2_500, 3_800, 2_400, 5_000, 3_200, 3_000, 2_800, 2_000]
        let industries: [Industry] = [.education, .services, .technology, .manufacturing, .services, .retail, .services, .technology, .education, .logistics, .retail, .education]
        return names.indices.map { i in HouseholdArchetype(id: i, name: names[i], monthlyIncome: incomes[i], essentialDaily: essentials[i], discretionaryDaily: incomes[i] / 130, savingPreference: 1_500 + i * 180, laborStatus: i == 0 || i == 11 ? .student : (i == 6 ? .retired : .employed), preferredIndustry: industries[i]) }
    }()
    public static func create(configuration c: SimulationConfiguration) throws -> SimulationState {
        try c.validate()
        var random = SplitMix64(seed: c.seed)
        let districtNames = ["Financial Core", "Innovation Quarter", "Harbor District", "Industrial Zone", "University District", "Residential Heights"]
        let industries: [Industry] = [.services, .technology, .logistics, .manufacturing, .education, .retail]
        let incomes = [12_000, 11_500, 9_500, 9_000, 8_500, 10_000]
        let demand = [11_500, 11_000, 9_500, 9_000, 8_500, 10_500]
        let weights = [5, 4, 3, 4, 2, 2]
        let districts = districtNames.indices.map { District(id: "district-\($0)", name: districtNames[$0], dominantIndustry: industries[$0], incomeMultiplier: incomes[$0], consumptionMultiplier: demand[$0], businessWeight: weights[$0]) }
        var ledger = Ledger()
        var banks: [Bank] = []
        for i in 0..<c.bankCount {
            let id = "bank-\(i)", account = "funding-\(i)"
            banks.append(Bank(id: id, name: ["Civic", "Harbor", "Pioneer", "Union"][i % 4] + " Bank \(i + 1)", fundingAccountID: account))
            try ledger.open(LedgerAccount(id: account, ownerID: id, bankID: id, kind: .bankFunding, balance: c.initialBankFunding))
        }
        try ledger.open(LedgerAccount(id: "treasury-account", ownerID: "treasury", bankID: nil, kind: .treasury, balance: c.initialTreasuryFunds))
        var businesses: [Business] = []
        let weightedDistricts = districts.flatMap { d in Array(repeating: d, count: d.businessWeight) }
        for i in 0..<c.businessCount {
            let district = weightedDistricts[i % weightedDistricts.count]
            let bank = i % banks.count
            let id = "business-\(i)", account = "business-deposit-\(i)"
            businesses.append(Business(id: id, name: "\(district.dominantIndustry.rawValue.capitalized) Works \(i + 1)", industry: district.dominantIndustry, districtID: district.id, bankID: banks[bank].id, accountID: account))
            banks[bank].customers.append(id)
            try ledger.open(LedgerAccount(id: account, ownerID: id, bankID: banks[bank].id, kind: .deposit, balance: c.initialBusinessDeposit))
        }
        var households: [Household] = []
        let firstNames = ["Alex", "Sam", "Morgan", "Robin", "Ari", "Jamie", "Riley", "Casey", "Noor", "Dev", "Mika", "Sage"]
        for i in 0..<c.population {
            let archetype = archetypes[i % archetypes.count]
            let districtIndex = random.integer(0...99) < 65 ? industries.firstIndex(of: archetype.preferredIndustry)! : random.integer(0...5)
            let district = districts[districtIndex], bank = random.integer(0...(banks.count - 1))
            let variation = random.integer(8_000...12_000)
            let id = "household-\(i)", deposit = "household-deposit-\(i)", cash = "household-cash-\(i)"
            let income = archetype.monthlyIncome * Int64(variation) / 10_000 * Int64(district.incomeMultiplier) / 10_000
            var household = Household(id: id, name: "\(firstNames[random.integer(0...(firstNames.count - 1))]) \(i + 1)", archetypeID: archetype.id, districtID: district.id, employment: archetype.laborStatus, bankID: banks[bank].id, depositAccountID: deposit, cashAccountID: cash, monthlyIncome: income, essentialDaily: archetype.essentialDaily * Int64(variation) / 10_000, discretionaryDaily: archetype.discretionaryDaily * Int64(variation) / 10_000, savingPreference: archetype.savingPreference, personalVariation: variation)
            if household.employment == .employed {
                let preferred = businesses.indices.filter { businesses[$0].industry == archetype.preferredIndustry }
                let choices = preferred.isEmpty ? Array(businesses.indices) : preferred
                let employer = choices[random.integer(0...(choices.count - 1))]
                household.employerID = businesses[employer].id
                businesses[employer].employees.append(id)
            }
            households.append(household); banks[bank].customers.append(id)
            try ledger.open(LedgerAccount(id: deposit, ownerID: id, bankID: banks[bank].id, kind: .deposit, balance: c.initialHouseholdDeposit * Int64(variation) / 10_000))
            try ledger.open(LedgerAccount(id: cash, ownerID: id, bankID: nil, kind: .cash, balance: 0))
        }
        var state = SimulationState(configuration: c, day: 0, random: random, archetypes: archetypes, households: households, businesses: businesses, banks: banks, districts: districts, treasury: Treasury(id: "treasury", accountID: "treasury-account"), centralBank: CentralBank(id: "central-bank", annualRateBasisPoints: c.initialPolicyRate), loans: [], ledger: ledger, journal: [], appliedEventIDs: [], currentMetrics: EconomyMetrics(), history: [], archetypeConfidence: Array(repeating: 7_000, count: 12))
        // Opening loans are funded, auditable transfers after every opening allocation is recorded.
        for i in state.households.indices where i % 3 == 0 {
            _ = EconomicKernel.originate(borrowerID: state.households[i].id, accountID: state.households[i].depositAccountID, bankID: state.households[i].bankID, amount: 180_000, state: &state)
        }
        if let player = c.player { try PlayerEnrollment.apply(player, state: &state) }
        state.recalculate(); state.history = [state.currentMetrics]
        return state
    }
}
