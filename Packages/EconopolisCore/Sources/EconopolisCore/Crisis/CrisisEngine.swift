import Foundation

/// Extensions to the existing daily pipeline. No separate simulation clock or economic state.
public enum CrisisEngine {
  static func record(
    _ origin: String, entity: String, message: String, amount: Money = 0, transaction: Int? = nil,
    state s: inout SimulationState
  ) {
    guard s.crisis != nil else { return }
    let id = "cause-\(s.crisis!.nextRecordID)"
    s.crisis!.nextRecordID += 1
    s.crisis!.records.append(
      CausalRecord(
        id: id, day: s.day, originID: origin, entityID: entity, message: message, amount: amount,
        transactionID: transaction))
    if s.crisis!.records.count > 600 {
      s.crisis!.records.removeFirst(s.crisis!.records.count - 600)
    }
  }
  static func activate(_ plan: CrisisPlan, state s: inout SimulationState) {
    if s.crisis == nil { s.crisis = CrisisState() }
    guard !s.crisis!.plans.contains(where: { $0.id == plan.id }) else { return }
    s.crisis!.plans.append(plan)
    record(
      plan.id, entity: plan.targetID ?? "economy", message: "\(plan.kind.rawValue) began", state: &s
    )
    if plan.kind == .interestRate {
      if s.crisis!.rateBeforeShocks == nil {
        s.crisis!.rateBeforeShocks = s.centralBank.annualRateBasisPoints
      }
      s.centralBank.annualRateBasisPoints = plan.rateBasisPoints
    }
    if plan.kind == .layoffs {
      for i in s.households.indices where s.households[i].employment == .employed {
        let h = s.households[i]
        let employer = s.businesses.first { $0.id == h.employerID }
        let eligible =
          plan.targetID == nil || h.districtID == plan.targetID
          || employer?.industry.rawValue == plan.targetID
        if eligible && deterministic(h.id, day: s.day) < plan.severity {
          if let b = s.businesses.firstIndex(where: { $0.id == h.employerID }) {
            s.businesses[b].employees.removeAll { $0 == h.id }
          }
          s.households[i].employment = .unemployed
          s.households[i].employerID = nil
          s.households[i].financialStress = min(10_000, h.financialStress + 2_000)
          s.journal.append(
            JournalEvent(day: s.day, entityID: h.id, message: "Employment ended through \(plan.id)")
          )
          record(
            plan.id, entity: h.id, message: "Employment ended; payroll obligation removed",
            amount: h.monthlyIncome, state: &s)
        }
      }
    }
  }
  static func policy(_ plan: PolicyPlan, state s: inout SimulationState) {
    if s.crisis == nil { s.crisis = CrisisState() }
    guard !s.crisis!.policies.contains(where: { $0.id == plan.id }) else { return }
    s.crisis!.policies.append(plan)
    switch plan.kind {
    case .liquidity:
      guard let bank = s.banks.first(where: { $0.id == plan.targetID }), plan.amount > 0 else {
        return
      }
      s.ledger.registerZero(id: "central-bank-account", owner: s.centralBank.id, kind: .treasury)
      s.ledger.changeSupply(
        account: "central-bank-account", amount: plan.amount, day: s.day,
        reason: "Temporary central-bank advance \(plan.id)")
      let tx = s.ledger.transfer(
        from: "central-bank-account", to: bank.fundingAccountID, amount: plan.amount,
        kind: .emergencyLiquidity, day: s.day)
      if tx.settled {
        s.crisis!.publicLoans.append(
          PublicLoan(
            id: plan.id, borrowerID: bank.id, accountID: bank.fundingAccountID, centralBank: true,
            original: plan.amount, outstanding: plan.amount, rate: plan.rateBasisPoints,
            dueDay: s.day + 30))
        s.centralBank.emergencyFunding += plan.amount
        s.crisis!.suspendedBanks.removeAll { $0 == bank.id }
        s.crisis!.illiquidDays[bank.id] = 0
        record(
          plan.id, entity: bank.id,
          message: "Central-bank liquidity issued against an explicit repayable claim",
          amount: plan.amount, transaction: tx.id, state: &s)
      }
    case .guarantee:
      record(
        plan.id, entity: plan.targetID ?? "economy",
        message: "Time-limited confidence assurance; no money transferred", state: &s)
    case .rate:
      s.centralBank.annualRateBasisPoints = plan.rateBasisPoints
      if s.crisis!.rateBeforeShocks != nil { s.crisis!.rateBeforeShocks = plan.rateBasisPoints }
    case .relief:
      var budget = min(plan.amount, s.ledger.balance(s.treasury.accountID))
      for h in s.households where plan.targetID == nil || h.districtID == plan.targetID {
        guard budget > 0 else { break }
        if h.depositBalance + h.cashBalance < 250_000 || h.employment == .unemployed {
          let amount = min(50_000, budget)
          let tx = s.ledger.transfer(
            from: s.treasury.accountID, to: h.depositAccountID, amount: amount, kind: .grant,
            day: s.day)
          if tx.settled {
            budget -= amount
            s.crisis!.fiscalCost += amount
            record(
              plan.id, entity: h.id, message: "Treasury-funded relief settled", amount: amount,
              transaction: tx.id, state: &s)
          }
        }
      }
    case .businessCredit:
      var budget = min(plan.amount, s.ledger.balance(s.treasury.accountID))
      for b in s.businesses
      where b.status != .failed && (plan.targetID == nil || b.districtID == plan.targetID)
        && b.operatingBalance < max(1, b.payrollObligation)
      {
        guard budget > 0 else { break }
        let amount = min(1_000_000, budget)
        let tx = s.ledger.transfer(
          from: s.treasury.accountID, to: b.accountID, amount: amount, kind: .loanAdvance,
          day: s.day)
        if tx.settled {
          budget -= amount
          s.crisis!.publicLoans.append(
            PublicLoan(
              id: "\(plan.id)-\(b.id)", borrowerID: b.id, accountID: b.accountID,
              centralBank: false, original: amount, outstanding: amount, rate: plan.rateBasisPoints,
              dueDay: s.day + 30))
          s.crisis!.fiscalCost += amount
          record(
            plan.id, entity: b.id, message: "Treasury-funded business loan settled", amount: amount,
            transaction: tx.id, state: &s)
        }
      }
    }
  }
  static func begin(_ s: inout SimulationState) {
    guard let crisis = s.crisis else { return }
    s.ledger.clearSettlementRules()
    var blocked: Set<String> = []
    let active = crisis.plans.filter { $0.isActive(day: s.day) }
    for bank in s.banks
    where !active.contains(where: { $0.kind == .bankRun && $0.targetID == bank.id }) {
      s.crisis!.pressure[bank.id] = 0
      s.crisis!.illiquidDays[bank.id] = 0
      s.crisis!.suspendedBanks.removeAll { $0 == bank.id }
    }
    if crisis.plans.contains(where: {
      $0.kind == .interestRate && $0.startDay + $0.duration == s.day
    }) {
      s.centralBank.annualRateBasisPoints =
        active.last(where: { $0.kind == .interestRate })?.rateBasisPoints ?? crisis.rateBeforeShocks
        ?? s.centralBank.annualRateBasisPoints
      if !active.contains(where: { $0.kind == .interestRate }) { s.crisis!.rateBeforeShocks = nil }
    }
    for plan in active where plan.kind == .paymentOutage {
      for h in s.households
      where plan.targetID == nil || h.bankID == plan.targetID || h.districtID == plan.targetID {
        blocked.insert(h.depositAccountID)
      }
      for b in s.businesses
      where plan.targetID == nil || b.bankID == plan.targetID || b.districtID == plan.targetID {
        blocked.insert(b.accountID)
      }
    }
    s.ledger.setBlocked(blocked)
    for plan in active where plan.kind == .recession {
      for i in s.households.indices {
        s.households[i].confidence = max(500, s.households[i].confidence - plan.severity / 12)
      }
      for i in s.archetypeConfidence.indices {
        s.archetypeConfidence[i] = max(500, s.archetypeConfidence[i] - plan.severity / 15)
      }
    }
    for plan in active where plan.kind == .bankRun {
      guard let bank = s.banks.first(where: { $0.id == plan.targetID }) else { continue }
      // Fully backed custody deposits have an explicitly constrained daily cash-conversion/settlement window.
      // Emergency unencumbered reserves increase the accessible window; no deposits are destroyed.
      let guarantee = crisis.policies.contains {
        $0.kind == .guarantee && ($0.targetID == nil || $0.targetID == bank.id) && s.day >= $0.day
          && s.day < $0.day + $0.duration
      }
      let severity = guarantee ? plan.severity / 4 : plan.severity
      let capacity =
        s.ledger.balance(bank.fundingAccountID) + bank.depositLiabilities
        * Int64(10_000 - plan.severity) / 100_000
      s.ledger.setLimit(bank: bank.id, amount: capacity)
      var requested: Money = 0
      var settled: Money = 0
      for i in s.households.indices where s.households[i].bankID == bank.id {
        let h = s.households[i]
        let amount = s.ledger.balance(h.depositAccountID) * Int64(severity) / 20_000
        if amount <= 0 { continue }
        requested += amount
        let tx = s.ledger.transfer(
          from: h.depositAccountID, to: h.cashAccountID, amount: amount, kind: .withdrawal,
          day: s.day)
        if tx.settled {
          settled += amount
        } else {
          record(
            plan.id, entity: h.id,
            message: "Cash conversion request could not settle within accessible bank reserves",
            amount: amount, transaction: tx.id, state: &s)
        }
        s.households[i].confidence = max(
          500, h.confidence - (tx.settled ? severity / 30 : severity / 8))
      }
      s.crisis!.requestedWithdrawals += requested
      s.crisis!.settledWithdrawals += settled
      s.crisis!.unmetWithdrawals += requested - settled
      let pressure = requested == 0 ? 0 : Int((requested - settled) * 10_000 / requested)
      s.crisis!.pressure[bank.id] = pressure
      s.crisis!.illiquidDays[bank.id] =
        pressure > 0 ? crisis.illiquidDays[bank.id, default: 0] + 1 : 0
      if s.crisis!.illiquidDays[bank.id, default: 0] >= 5
        && !s.crisis!.suspendedBanks.contains(bank.id)
      {
        s.crisis!.suspendedBanks.append(bank.id)
        record(
          plan.id, entity: bank.id,
          message:
            "Settlement resolution after five consecutive days of unmet withdrawal obligations; deposits remain claims",
          amount: requested - settled, state: &s)
      }
      record(
        plan.id, entity: bank.id, message: "Daily withdrawal requests / settled cash conversion",
        amount: settled, state: &s)
    }
    for bank in s.crisis!.suspendedBanks {
      // A suspension lasts only through active crisis conditions; restart restores payment availability.
      if active.contains(where: { $0.kind == .bankRun && $0.targetID == bank }) {
        s.ledger.setLimit(
          bank: bank,
          amount: s.ledger.balance(s.banks.first { $0.id == bank }?.fundingAccountID ?? ""))
      }
    }
    servicePublicLoans(&s)
    let recovered = s.ledger.retryQueued(day: s.day)
    for tx in recovered {
      if tx.kind == .payroll, let b = s.businesses.firstIndex(where: { $0.accountID == tx.sender })
      {
        s.businesses[b].expenses += tx.amount
      }
      if tx.kind == .payroll, tx.amount / 10 > 0 {
        let tax = s.ledger.transfer(
          from: tx.recipient, to: s.treasury.accountID, amount: tx.amount / 10, kind: .tax,
          day: s.day)
        if tax.settled { s.treasury.taxCollected += tax.amount }
      }
      if tx.kind == .benefit { s.treasury.benefitsPaid += tx.amount }
      record(
        "payment-recovery", entity: s.ledger.accounts[tx.recipient]?.ownerID ?? tx.recipient,
        message: "Previously delayed payment settled", amount: tx.amount, transaction: tx.id,
        state: &s)
    }
  }
  static func finish(_ s: inout SimulationState) {
    guard s.crisis != nil else { return }
    let origin = s.crisis!.plans.last(where: { $0.isActive(day: s.day) })?.id
    if let origin {
      for event in s.journal.reversed().prefix(while: { $0.day == s.day })
      where event.message.contains("Employment ended") || event.message.contains("Business closed")
        || event.message.contains("Loan default")
      {
        record(
          origin, entity: event.entityID, message: "Observed during crisis: \(event.message)",
          state: &s)
      }
    }
    let currentFailures = s.ledger.rejectedTransactions.reversed().prefix { $0.day == s.day }
    for tx in currentFailures
    where tx.rejection == .liquidityUnavailable || tx.rejection == .networkUnavailable {
      if let owner = s.ledger.accounts[tx.sender]?.ownerID,
        s.businesses.contains(where: { $0.id == owner })
      {
        let sender = s.ledger.accounts[tx.sender]
        let recipient = s.ledger.accounts[tx.recipient]
        let owners = [sender?.ownerID, recipient?.ownerID].compactMap { $0 }
        let districts =
          s.households.filter { owners.contains($0.id) }.map(\.districtID)
          + s.businesses.filter { owners.contains($0.id) }.map(\.districtID)
        let origin =
          s.crisis!.plans.last { plan in
            guard plan.isActive(day: s.day) else { return false }
            if tx.rejection == .liquidityUnavailable {
              return plan.kind == .bankRun && plan.targetID == sender?.bankID
            }
            return plan.kind == .paymentOutage
              && (plan.targetID == nil
                || [sender?.bankID, recipient?.bankID].contains(plan.targetID)
                || districts.contains(plan.targetID ?? ""))
          }?.id ?? "settlement"
        record(
          origin, entity: owner,
          message:
            "Business payment disrupted through bank/payment exposure", amount: tx.amount,
          transaction: tx.id, state: &s)
      }
    }
  }
  static func lendingAllowed(bank: String, state s: SimulationState) -> Bool {
    !(s.crisis?.plans.contains {
      $0.kind == .creditCrunch && $0.isActive(day: s.day)
        && ($0.targetID == nil || $0.targetID == bank)
    } ?? false)
  }
  static func hiringAllowed(_ s: SimulationState) -> Bool {
    !(s.crisis?.plans.contains { $0.kind == .recession && $0.isActive(day: s.day) } ?? false)
  }
  private static func deterministic(_ id: String, day: Int) -> Int {
    var value = UInt64(day)
    for byte in id.utf8 { value = (value &* 1_099_511_628_211) ^ UInt64(byte) }
    return Int(value % 10_000)
  }
  private static func servicePublicLoans(_ s: inout SimulationState) {
    guard s.crisis != nil else { return }
    for i in s.crisis!.publicLoans.indices {
      let loan = s.crisis!.publicLoans[i]
      guard loan.outstanding > 0, loan.dueDay <= s.day else { continue }
      let principal = min(loan.outstanding, max(1, loan.original / 12))
      let interest = loan.outstanding * Int64(loan.rate) * 30 / 3_650_000
      let recipient = loan.centralBank ? "central-bank-account" : s.treasury.accountID
      if s.ledger.balance(loan.accountID) >= principal + interest
        && !s.ledger.isBlocked(loan.accountID)
      {
        let tx = s.ledger.transfer(
          from: loan.accountID, to: recipient, amount: principal, kind: .principal, day: s.day)
        if tx.settled {
          s.crisis!.publicLoans[i].outstanding -= principal
          if loan.centralBank {
            s.ledger.changeSupply(
              account: recipient, amount: -principal, day: s.day,
              reason: "Central-bank principal extinguishment \(loan.id)")
          }
          if interest > 0 {
            s.ledger.transfer(
              from: loan.accountID, to: s.treasury.accountID, amount: interest, kind: .interest,
              day: s.day)
          }
        }
      } else {
        s.crisis!.publicLoans[i].missed += 1
      }
      s.crisis!.publicLoans[i].dueDay += 30
    }
    s.centralBank.emergencyFunding = s.crisis!.emergencyClaims
  }
}
