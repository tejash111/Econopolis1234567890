import Foundation

public struct PlayerProfile: Codable, Sendable, Equatable {
    public var name: String
    public var districtID: String
    public var archetypeID: Int
    public var startingDeposit: Money
    public var savingPreference: Int
    public var riskTolerance: Int
    public init(name: String, districtID: String, archetypeID: Int, startingDeposit: Money, savingPreference: Int = 3_000, riskTolerance: Int = 5_000) {
        self.name = name; self.districtID = districtID; self.archetypeID = archetypeID; self.startingDeposit = startingDeposit; self.savingPreference = savingPreference; self.riskTolerance = riskTolerance
    }
    public func validate() throws {
        guard (1...40).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count), (0..<12).contains(archetypeID), (0...2_000_000).contains(startingDeposit), (0...10_000).contains(savingPreference), (0...10_000).contains(riskTolerance) else { throw SimulationError.invalidConfiguration }
    }
}
enum PlayerEnrollment {
    static func apply(_ profile: PlayerProfile, state s: inout SimulationState) throws {
        try profile.validate()
        guard let index = s.households.indices.last, let district = s.districts.first(where: { $0.id == profile.districtID }) else { throw SimulationError.invalidConfiguration }
        let previous = s.households[index], archetype = s.archetypes[profile.archetypeID]
        for i in s.businesses.indices { s.businesses[i].employees.removeAll { $0 == previous.id } }
        // Retire any generated opening loan before applying the player's debt-free starting preset.
        for loanIndex in s.loans.indices where s.loans[loanIndex].borrowerID == previous.id {
            let loan = s.loans[loanIndex]
            guard let bank = s.banks.first(where: { $0.id == loan.bankID }) else { continue }
            if s.ledger.transfer(from: previous.depositAccountID, to: bank.fundingAccountID, amount: loan.outstandingPrincipal, kind: .principal, day: 0).settled { s.loans[loanIndex].outstandingPrincipal = 0 }
        }
        var person = Household(id: previous.id, name: profile.name.trimmingCharacters(in: .whitespacesAndNewlines), archetypeID: profile.archetypeID, districtID: district.id, employment: archetype.laborStatus, bankID: previous.bankID, depositAccountID: previous.depositAccountID, cashAccountID: previous.cashAccountID, monthlyIncome: archetype.monthlyIncome * Int64(district.incomeMultiplier) / 10_000, essentialDaily: archetype.essentialDaily, discretionaryDaily: archetype.discretionaryDaily, savingPreference: profile.savingPreference, personalVariation: 9_000 + profile.riskTolerance / 5)
        person.confidence = 6_000 + profile.riskTolerance / 4
        if person.employment == .employed {
            let candidate = s.businesses.firstIndex { $0.districtID == district.id && $0.industry == archetype.preferredIndustry } ?? s.businesses.firstIndex { $0.districtID == district.id }
            if let employer = candidate { person.employerID = s.businesses[employer].id; s.businesses[employer].employees.append(person.id) } else { person.employment = .unemployed }
        }
        s.households[index] = person
        let difference = profile.startingDeposit - s.ledger.balance(person.depositAccountID)
        if difference > 0 { s.ledger.transfer(from: s.treasury.accountID, to: person.depositAccountID, amount: min(difference, s.ledger.balance(s.treasury.accountID)), kind: .grant, day: 0) }
        else if difference < 0 { s.ledger.transfer(from: person.depositAccountID, to: s.treasury.accountID, amount: -difference, kind: .grant, day: 0) }
        s.journal.append(JournalEvent(day: 0, entityID: person.id, message: "Fictional citizen joined a new shared baseline; deposit preset reconciled through treasury transfers"))
    }
}
