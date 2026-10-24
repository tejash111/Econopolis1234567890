import Foundation

public enum AccountKind: String, Codable, Sendable { case deposit, cash, bankFunding, treasury }
public struct LedgerAccount: Codable, Sendable, Equatable, Identifiable {
    public let id: EntityID
    public let ownerID: EntityID
    public let bankID: EntityID?
    public let kind: AccountKind
    public var balance: Money
    public init(id: EntityID, ownerID: EntityID, bankID: EntityID?, kind: AccountKind, balance: Money) {
        self.id = id; self.ownerID = ownerID; self.bankID = bankID; self.kind = kind; self.balance = balance
    }
}
public enum TransactionKind: String, Codable, Sendable { case essential, discretionary, payroll, tax, benefit, operatingExpense, loanAdvance, principal, interest, grant, withdrawal, cashDeposit, emergencyLiquidity }
public enum RejectionReason: String, Codable, Sendable { case invalidAmount, missingAccount, insufficientFunds, sameAccount, networkUnavailable, liquidityUnavailable }
public struct Transaction: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let day: Int
    public let sender: EntityID
    public let recipient: EntityID
    public let amount: Money
    public let kind: TransactionKind
    public let rejection: RejectionReason?
    public var settled: Bool { rejection == nil }
}
public struct LedgerEntry: Codable, Sendable, Equatable {
    public let transactionID: Int
    public let accountID: EntityID
    public let delta: Money
}
public struct OpeningAllocation: Codable, Sendable, Equatable {
    public let accountID: EntityID
    public let amount: Money
    public let source: String
}
public struct Reconciliation: Codable, Sendable, Equatable {
    public let openingMoney: Money
    public let currentMoney: Money
    public let entryNet: Money
    public let accountsMatchJournal: Bool
    public let nonnegative: Bool
    public var isBalanced: Bool { openingMoney == currentMoney && entryNet == 0 && accountsMatchJournal && nonnegative }
}

/// Exclusive authority for spendable balances. Bank reserves are derived custodial assets, not another spendable account.
public struct Ledger: Codable, Sendable, Equatable {
    public private(set) var accounts: [EntityID: LedgerAccount] = [:]
    public private(set) var openingAllocations: [OpeningAllocation] = []
    public private(set) var settledTransactions: [Transaction] = []
    public private(set) var rejectedTransactions: [Transaction] = []
    public private(set) var entries: [LedgerEntry] = []
public private(set) var supplyChanges: [MoneySupplyChange]? = nil
public private(set) var queuedPayments: [QueuedPayment]? = nil
private var blockedAccounts: Set<String>? = nil
private var settlementLimits: [String: Money]? = nil
public mutating func registerZero(id: String, owner: String, kind: AccountKind) {
    guard accounts[id] == nil else { return }
    accounts[id] = LedgerAccount(id: id, ownerID: owner, bankID: nil, kind: kind, balance: 0)
    openingAllocations.append(OpeningAllocation(accountID: id, amount: 0, source: "Zero-balance settlement account registration"))
}
@discardableResult public mutating func changeSupply(account: String, amount: Money, day: Int, reason: String) -> Bool {
    guard accounts[account] != nil, amount != 0, amount >= -balance(account), (-1_000_000_000...1_000_000_000).contains(amount) else { return false }
    accounts[account]!.balance += amount
    if supplyChanges == nil { supplyChanges = [] }
    supplyChanges!.append(MoneySupplyChange(day: day, accountID: account, amount: amount, reason: reason))
    return true
}
public mutating func clearSettlementRules() { blockedAccounts = nil; settlementLimits = nil }
public mutating func setBlocked(_ ids: Set<String>) { blockedAccounts = ids }
public mutating func setLimit(bank: String, amount: Money) { if settlementLimits == nil { settlementLimits = [:] }; settlementLimits![bank] = max(0, amount) }
public func isBlocked(_ id: String) -> Bool { blockedAccounts?.contains(id) ?? false }
public mutating func retryQueued(day: Int) -> [Transaction] {
    let queue = queuedPayments ?? []
    queuedPayments = []
    var settled: [Transaction] = []
    for request in queue {
        if isBlocked(request.sender) || isBlocked(request.recipient) { queuedPayments!.append(request); continue }
        let tx = transfer(from: request.sender, to: request.recipient, amount: request.amount, kind: request.kind, day: day, recordQueue: false)
        if tx.settled { settled.append(tx) } else { queuedPayments!.append(request) }
    }
    return settled
}
    private var nextID = 1
    public init() {}
    public mutating func open(_ account: LedgerAccount) throws {
        guard account.balance >= 0, account.balance <= 1_000_000_000_000,
              accounts[account.id] == nil, settledTransactions.isEmpty, rejectedTransactions.isEmpty else {
            throw SimulationError.invalidSnapshot("Invalid opening allocation")
        }
        accounts[account.id] = account
        openingAllocations.append(OpeningAllocation(accountID: account.id, amount: account.balance, source: "Initial external endowment (day 0)"))
    }
    public func balance(_ id: EntityID) -> Money { accounts[id]?.balance ?? 0 }
    @discardableResult public mutating func transfer(from: EntityID, to: EntityID, amount: Money, kind: TransactionKind, day: Int, recordQueue: Bool = true) -> Transaction {
        let reason: RejectionReason?
        if amount <= 0 { reason = .invalidAmount }
        else if from == to { reason = .sameAccount }
        else if accounts[from] == nil || accounts[to] == nil { reason = .missingAccount }
        else if isBlocked(from) || isBlocked(to) { reason = .networkUnavailable }
        else if let bank = accounts[from]?.bankID, accounts[from]?.kind == .deposit, accounts[to]?.bankID != bank, let limit = settlementLimits?[bank], amount > limit { reason = .liquidityUnavailable }
        else if balance(from) < amount { reason = .insufficientFunds }
        else { reason = nil }
        let transaction = Transaction(id: nextID, day: day, sender: from, recipient: to, amount: amount, kind: kind, rejection: reason)
        nextID += 1
        if reason == nil {
            if let bank = accounts[from]?.bankID, accounts[from]?.kind == .deposit, accounts[to]?.bankID != bank, settlementLimits?[bank] != nil { settlementLimits![bank]! -= amount }
            accounts[from]!.balance -= amount; accounts[to]!.balance += amount
            settledTransactions.append(transaction)
            entries.append(LedgerEntry(transactionID: transaction.id, accountID: from, delta: -amount))
            entries.append(LedgerEntry(transactionID: transaction.id, accountID: to, delta: amount))
        } else {
            rejectedTransactions.append(transaction)
            if recordQueue, (reason == .networkUnavailable || reason == .liquidityUnavailable), kind == .payroll || kind == .benefit {
                if queuedPayments == nil { queuedPayments = [] }
                queuedPayments!.append(QueuedPayment(id: transaction.id, sender: from, recipient: to, amount: amount, kind: kind, requestedDay: day))
            }
        }

        return transaction
    }
    public func reconcile() -> Reconciliation {
        var reconstructed: [EntityID: Money] = [:]
        for allocation in openingAllocations { reconstructed[allocation.accountID, default: 0] += allocation.amount }
        for change in supplyChanges ?? [] { reconstructed[change.accountID, default: 0] += change.amount }
        for entry in entries { reconstructed[entry.accountID, default: 0] += entry.delta }
        let postingsMatch = entries.count == settledTransactions.count * 2 && settledTransactions.enumerated().allSatisfy { index, tx in
            guard tx.settled, tx.amount > 0 else { return false }
            let debit = entries[index * 2], credit = entries[index * 2 + 1]
            return debit.transactionID == tx.id && credit.transactionID == tx.id && debit.accountID == tx.sender && credit.accountID == tx.recipient && debit.delta == -tx.amount && credit.delta == tx.amount
        }
        let allIDs = settledTransactions.map(\.id) + rejectedTransactions.map(\.id)
        let uniqueJournal = Set(allIDs).count == allIDs.count && rejectedTransactions.allSatisfy { !$0.settled }
        return Reconciliation(openingMoney: openingAllocations.reduce(0) { $0 + $1.amount } + (supplyChanges ?? []).reduce(0) { $0 + $1.amount },
                              currentMoney: accounts.values.reduce(0) { $0 + $1.balance },
                              entryNet: entries.reduce(0) { $0 + $1.delta },
                              accountsMatchJournal: postingsMatch && uniqueJournal && reconstructed.count == accounts.count && accounts.allSatisfy { reconstructed[$0.key] == $0.value.balance },
                              nonnegative: accounts.values.allSatisfy { $0.balance >= 0 })
    }
}
