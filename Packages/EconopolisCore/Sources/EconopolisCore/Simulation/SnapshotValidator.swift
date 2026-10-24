import Foundation

public enum SnapshotValidator {
    public static func validate(_ snapshot: SimulationSnapshot) throws {
        let s = snapshot.state
        func require(_ condition: Bool, _ reason: String) throws {
            if !condition { throw SimulationError.invalidSnapshot(reason) }
        }
        try s.configuration.validate()
        try require(snapshot.schemaVersion == 1 && (0...1_000_000).contains(s.day), "Unsupported schema or day")
        try require(s.households.count == s.configuration.population && s.businesses.count == s.configuration.businessCount && s.banks.count == s.configuration.bankCount && s.districts.count == 6 && s.archetypes == WorldGenerator.archetypes && s.archetypeConfidence.count == 12, "World dimensions")
        let householdIDs = Set(s.households.map(\.id)), businessIDs = Set(s.businesses.map(\.id)), bankIDs = Set(s.banks.map(\.id)), districtIDs = Set(s.districts.map(\.id))
        try require(householdIDs.count == s.households.count && businessIDs.count == s.businesses.count && bankIDs.count == s.banks.count && districtIDs.count == s.districts.count && Set(s.loans.map(\.id)).count == s.loans.count, "Duplicate entity IDs")
        try require(s.ledger.reconcile().isBalanced, "Ledger does not reconcile")
        try require((0...10_000).contains(s.centralBank.annualRateBasisPoints), "Invalid policy rate")
        for h in s.households {
            try require((0..<12).contains(h.archetypeID) && districtIDs.contains(h.districtID) && bankIDs.contains(h.bankID), "Household reference")
            try require(h.employerID == nil || businessIDs.contains(h.employerID!), "Missing employer")
            try require((h.employment == .employed) == (h.employerID != nil), "Employment mismatch")
            try require(s.ledger.accounts[h.depositAccountID]?.ownerID == h.id && s.ledger.accounts[h.depositAccountID]?.bankID == h.bankID && s.ledger.accounts[h.depositAccountID]?.kind == .deposit && s.ledger.accounts[h.cashAccountID]?.ownerID == h.id, "Household account")
            try require([h.monthlyIncome, h.essentialDaily, h.discretionaryDaily].allSatisfy { (0...1_000_000_000).contains($0) } && (0...10_000).contains(h.confidence) && (0...10_000).contains(h.financialStress), "Household bounds")
        }
        for b in s.businesses {
            try require(districtIDs.contains(b.districtID) && bankIDs.contains(b.bankID) && s.ledger.accounts[b.accountID]?.ownerID == b.id && s.ledger.accounts[b.accountID]?.bankID == b.bankID, "Business reference")
            let actual = Set(s.households.filter { $0.employerID == b.id }.map(\.id))
            try require(Set(b.employees) == actual && b.employees.count == actual.count, "Employment roster mismatch")
        }
        for b in s.banks {
            try require(s.ledger.accounts[b.fundingAccountID]?.kind == .bankFunding && s.ledger.accounts[b.fundingAccountID]?.ownerID == b.id, "Bank funding account")
            try require(Set(b.customers) == Set(s.households.filter { $0.bankID == b.id }.map(\.id) + s.businesses.filter { $0.bankID == b.id }.map(\.id)), "Bank customers")
            try require(Set(b.loanIDs) == Set(s.loans.filter { $0.bankID == b.id }.map(\.id)), "Bank loan portfolio")
        }
        for a in s.ledger.accounts.values {
            try require(a.bankID == nil || bankIDs.contains(a.bankID!), "Account bank reference")
            try require(householdIDs.contains(a.ownerID) || businessIDs.contains(a.ownerID) || bankIDs.contains(a.ownerID) || (a.ownerID == s.treasury.id || a.ownerID == s.centralBank.id), "Account owner")
        }
        try require(s.ledger.accounts[s.treasury.accountID]?.kind == .treasury, "Treasury account")
        for loan in s.loans {
            try require(bankIDs.contains(loan.bankID) && (householdIDs.contains(loan.borrowerID) || businessIDs.contains(loan.borrowerID)) && s.ledger.accounts[loan.borrowerAccountID]?.ownerID == loan.borrowerID, "Loan reference")
            try require(loan.originalPrincipal > 0 && loan.originalPrincipal <= 2_000_000 && (0...loan.originalPrincipal).contains(loan.outstandingPrincipal) && loan.installmentPrincipal > 0 && loan.intervalDays == 30 && loan.nextPaymentDay > 0 && loan.maturityDay >= 30 && (0...10_000).contains(loan.annualSpreadBasisPoints), "Loan schedule")
        }
    }
}
