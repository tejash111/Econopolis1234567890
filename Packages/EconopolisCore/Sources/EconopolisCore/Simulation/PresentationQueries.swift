import Foundation

public struct EntityEvidence: Sendable {
    public let household: Household?
    public let transactions: [Transaction]
    public let events: [JournalEvent]
    public let accountOwners: [String: String]
}
public enum PresentationQueries {
    static func evidence(id: String, state s: SimulationState) -> EntityEvidence {
        let districtOwners = Set(s.households.filter { $0.districtID == id }.map(\.id) + s.businesses.filter { $0.districtID == id }.map(\.id))
        let accounts = Set(s.ledger.accounts.values.filter { $0.ownerID == id || $0.bankID == id || districtOwners.contains($0.ownerID) }.map(\.id))
        let causal = s.crisis?.records.filter { $0.entityID == id }.map { JournalEvent(day: $0.day, entityID: id, message: $0.message + ($0.transactionID.map { " (transaction #\($0))" } ?? "")) } ?? []
        let events = (s.journal.filter { $0.entityID == id } + causal).sorted { $0.day > $1.day }
        return EntityEvidence(household: s.households.first { $0.id == id }, transactions: Array(s.ledger.settledTransactions.reversed().lazy.filter { accounts.contains($0.sender) || accounts.contains($0.recipient) }.prefix(30)), events: Array(events.prefix(30)), accountOwners: s.ledger.accounts.mapValues(\.ownerID))
    }
}
