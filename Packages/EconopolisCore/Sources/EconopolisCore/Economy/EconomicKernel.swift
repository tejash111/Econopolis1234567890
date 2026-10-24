import Foundation

/// Ordered, synchronous transitions; only SimulationEngine owns a live instance of state.
public enum EconomicKernel {
    @discardableResult static func originate(borrowerID: EntityID, accountID: EntityID, bankID: EntityID, amount: Money, state s: inout SimulationState) -> Bool {
        guard amount > 0, amount <= 2_000_000, CrisisEngine.lendingAllowed(bank: bankID, state: s),
              let bank = s.banks.firstIndex(where: { $0.id == bankID }), s.banks[bank].status == .normal,
              s.ledger.balance(s.banks[bank].fundingAccountID) >= amount,
              s.loans.filter({ $0.borrowerID == borrowerID && $0.outstandingPrincipal > 0 }).count < 2 else { return false }
        let tx = s.ledger.transfer(from: s.banks[bank].fundingAccountID, to: accountID, amount: amount, kind: .loanAdvance, day: s.day)
        guard tx.settled else { return false }
        let id = "loan-\(s.loans.count)"
        s.loans.append(Loan(id: id, borrowerID: borrowerID, borrowerAccountID: accountID, bankID: bankID, originalPrincipal: amount, outstandingPrincipal: amount, annualSpreadBasisPoints: 250, installmentPrincipal: max(1, (amount + 11) / 12), nextPaymentDay: s.day + 30, intervalDays: 30, maturityDay: s.day + 360))
        s.banks[bank].loanIDs.append(id)
        s.journal.append(JournalEvent(day: s.day, entityID: borrowerID, message: "Funded loan originated: \(amount) cents"))
        return true
    }

    public static func advance(_ s: inout SimulationState) {
        s.day += 1
        applyEvents(&s)
        for i in s.businesses.indices { s.businesses[i].revenue = 0; s.businesses[i].expenses = 0 }
        CrisisEngine.begin(&s)
        updateArchetypes(&s)
        consume(&s)
        operateBusinesses(&s)
        if s.day % 30 == 0 { payrollAndBenefits(&s) }
        serviceLoans(&s)
        updateStressAndEmployment(&s)
        CrisisEngine.finish(&s)
        s.recalculate()
        s.history.append(s.currentMetrics)
    }

    private static func applyEvents(_ s: inout SimulationState) {
        // Configuration order is preserved for events scheduled on the same day.
        for event in s.configuration.events where event.day == s.day && !s.appliedEventIDs.contains(event.id) {
            switch event.kind {
            case .crisis(let plan): CrisisEngine.activate(plan, state: &s)
            case .policy(let plan): CrisisEngine.policy(plan, state: &s)
            case .confidenceShock(let delta):
                for i in s.households.indices { s.households[i].confidence = bounded(s.households[i].confidence + max(-10_000, min(10_000, delta))) }
                for i in s.archetypeConfidence.indices { s.archetypeConfidence[i] = bounded(s.archetypeConfidence[i] + max(-10_000, min(10_000, delta))) }
            case .interestRate(let rate): s.centralBank.annualRateBasisPoints = max(0, min(10_000, rate))
            case .businessClosure(let id):
                if let i = s.businesses.firstIndex(where: { $0.id == id }) { closeBusiness(i, state: &s) }
            case .treasuryGrant(let id, let amount):
                if let h = s.households.first(where: { $0.id == id }) {
                    s.ledger.transfer(from: s.treasury.accountID, to: h.depositAccountID, amount: amount, kind: .grant, day: s.day)
                } else { s.journal.append(JournalEvent(day: s.day, entityID: id, message: "Grant rejected: missing household")) }
            }
            s.appliedEventIDs.append(event.id)
            s.journal.append(JournalEvent(day: s.day, entityID: event.id, message: "Scheduled economic event applied"))
        }
    }
    private static func updateArchetypes(_ s: inout SimulationState) {
        for a in s.archetypes {
            let members = s.households.filter { $0.archetypeID == a.id }
            let stress = members.isEmpty ? 0 : members.reduce(0) { $0 + $1.financialStress } / members.count
            let target = bounded(8_000 - stress / 2 - s.centralBank.annualRateBasisPoints)
            s.archetypeConfidence[a.id] += (target - s.archetypeConfidence[a.id]) / 12
        }
    }
    private static func consume(_ s: inout SimulationState) {
        let active = s.businesses.indices.filter { s.businesses[$0].status != .failed }
        for i in s.households.indices {
            let h = s.households[i]
            guard !active.isEmpty, let district = s.districts.first(where: { $0.id == h.districtID }) else { continue }
            let local = active.filter { s.businesses[$0].districtID == h.districtID }
            let choices = local.isEmpty ? active : local
            let seller = choices[draw(0...(choices.count - 1), household: i, channel: 0, state: &s)]
            let dailyVariation = draw(9_000...11_000, household: i, channel: 1, state: &s)
            let essential = h.essentialDaily * Int64(district.consumptionMultiplier) / 10_000 * Int64(dailyVariation) / 10_000
            let essentialPaid = purchase(h, seller: seller, amount: essential, kind: .essential, state: &s)
            let buffer = h.essentialDaily * Int64(7 + h.savingPreference / 500) + h.scheduledRepayment
            let room = max(0, s.ledger.balance(h.depositAccountID) + s.ledger.balance(h.cashAccountID) - buffer)
            let rateFactor = max(1_000, 10_000 - s.centralBank.annualRateBasisPoints * 2)
            let discretionary = h.discretionaryDaily * Int64(h.confidence) / 10_000 * Int64(rateFactor) / 10_000 * Int64(district.consumptionMultiplier) / 10_000
            let discretionaryPaid = purchase(h, seller: seller, amount: min(room, discretionary), kind: .discretionary, state: &s)
            if essentialPaid < essential { s.households[i].financialStress = bounded(h.financialStress + 600) }
            s.households[i].decisions.append(Decision(day: s.day, spending: essentialPaid + discretionaryPaid, confidence: h.confidence, reason: essentialPaid < essential ? "Essential budget shortfall" : (room == 0 ? "Preserving repayment and essential buffer" : "Bounded local consumption")))
            if s.households[i].decisions.count > 30 { s.households[i].decisions.removeFirst() }
        }
    }
    private static func purchase(_ h: Household, seller: Int, amount: Money, kind: TransactionKind, state s: inout SimulationState) -> Money {
        var paid: Money = 0
        let deposit = min(amount, s.ledger.balance(h.depositAccountID))
        if deposit > 0, s.ledger.transfer(from: h.depositAccountID, to: s.businesses[seller].accountID, amount: deposit, kind: kind, day: s.day).settled { paid += deposit }
        let cash = min(amount - paid, s.ledger.balance(h.cashAccountID))
        if cash > 0, s.ledger.transfer(from: h.cashAccountID, to: s.businesses[seller].accountID, amount: cash, kind: kind, day: s.day).settled { paid += cash }
        s.businesses[seller].revenue += paid
        return paid
    }
    private static func operateBusinesses(_ s: inout SimulationState) {
        for i in s.businesses.indices where s.businesses[i].status != .failed {
            // Municipal premises/services fee: a domestic transfer, no untracked external sink.
            let desired = Money(500 + s.businesses[i].employees.count * 80)
            let amount = min(desired, s.ledger.balance(s.businesses[i].accountID))
            if amount > 0 {
                if s.ledger.transfer(from: s.businesses[i].accountID, to: s.treasury.accountID, amount: amount, kind: .operatingExpense, day: s.day).settled { s.businesses[i].expenses += amount }
            }
        }
    }
    private static func payrollAndBenefits(_ s: inout SimulationState) {
        for b in s.businesses.indices where s.businesses[b].status != .failed {
            let employees = s.households.indices.filter { s.households[$0].employerID == s.businesses[b].id && s.households[$0].employment == .employed }
            let obligation = employees.reduce(Money(0)) { $0 + s.households[$1].monthlyIncome }
            let shortfall = max(0, obligation - s.ledger.balance(s.businesses[b].accountID))
            if shortfall > 0 { _ = originate(borrowerID: s.businesses[b].id, accountID: s.businesses[b].accountID, bankID: s.businesses[b].bankID, amount: shortfall, state: &s) }
            for i in employees {
                let h = s.households[i]
                let tx = s.ledger.transfer(from: s.businesses[b].accountID, to: h.depositAccountID, amount: h.monthlyIncome, kind: .payroll, day: s.day)
                if tx.settled {
                    s.businesses[b].expenses += h.monthlyIncome
                    let tax = h.monthlyIncome / 10
                    if tax > 0, s.ledger.transfer(from: h.depositAccountID, to: s.treasury.accountID, amount: tax, kind: .tax, day: s.day).settled { s.treasury.taxCollected += tax }
                } else if tx.rejection != .networkUnavailable && tx.rejection != .liquidityUnavailable {
                    s.households[i].financialStress = bounded(s.households[i].financialStress + 2_000)
                    dismiss(i, state: &s)
                    s.businesses[b].stressDays += 7
                }
            }
        }
        for h in s.households where h.employment != .employed {
            let benefit = h.employment == .unemployed ? h.monthlyIncome * 35 / 100 : h.monthlyIncome
            if benefit > 0, s.ledger.transfer(from: s.treasury.accountID, to: h.depositAccountID, amount: benefit, kind: .benefit, day: s.day).settled { s.treasury.benefitsPaid += benefit }
        }
    }
    private static func serviceLoans(_ s: inout SimulationState) {
        for i in s.loans.indices where !s.loans[i].defaulted && s.loans[i].outstandingPrincipal > 0 && s.loans[i].nextPaymentDay <= s.day {
            let loan = s.loans[i]
            guard let bank = s.banks.first(where: { $0.id == loan.bankID }) else { continue }
            let principal = s.day >= loan.maturityDay ? loan.outstandingPrincipal : min(loan.installmentPrincipal, loan.outstandingPrincipal)
            let interest = loan.outstandingPrincipal * Int64(s.centralBank.annualRateBasisPoints + loan.annualSpreadBasisPoints) * Int64(loan.intervalDays) / 3_650_000
if let h = s.households.first(where: { $0.id == loan.borrowerID }), s.ledger.balance(loan.borrowerAccountID) < principal + interest {
    let cash = min(s.ledger.balance(h.cashAccountID), principal + interest - s.ledger.balance(loan.borrowerAccountID))
    if cash > 0 { s.ledger.transfer(from: h.cashAccountID, to: h.depositAccountID, amount: cash, kind: .cashDeposit, day: s.day) }
}
if s.ledger.isBlocked(loan.borrowerAccountID) {
    s.ledger.transfer(from: loan.borrowerAccountID, to: bank.fundingAccountID, amount: principal + interest, kind: .principal, day: s.day)
    continue
}
if s.ledger.balance(loan.borrowerAccountID) >= principal + interest {

                let principalTx = s.ledger.transfer(from: loan.borrowerAccountID, to: bank.fundingAccountID, amount: principal, kind: .principal, day: s.day)
                guard principalTx.settled else { continue }
                if interest > 0 { s.ledger.transfer(from: loan.borrowerAccountID, to: bank.fundingAccountID, amount: interest, kind: .interest, day: s.day) }
                s.loans[i].outstandingPrincipal -= principal
                s.loans[i].interestPaid += interest; s.loans[i].missedPayments = 0
            } else {
                s.ledger.transfer(from: loan.borrowerAccountID, to: bank.fundingAccountID, amount: principal + interest, kind: .principal, day: s.day)
                s.loans[i].missedPayments += 1
                if s.loans[i].missedPayments >= 3 {
                    s.loans[i].defaulted = true
                    if let h = s.households.firstIndex(where: { $0.id == loan.borrowerID }) { s.households[h].defaulted = true }
                    s.journal.append(JournalEvent(day: s.day, entityID: loan.borrowerID, message: "Loan default; bank claim written off, borrower obligation retained"))
                }
            }
            s.loans[i].nextPaymentDay += loan.intervalDays
        }
    }
    private static func updateStressAndEmployment(_ s: inout SimulationState) {
        for b in s.businesses.indices where s.businesses[b].status != .failed {
            let payroll = s.households.filter { $0.employerID == s.businesses[b].id && $0.employment == .employed }.reduce(Money(0)) { $0 + $1.monthlyIncome }
            let funds = s.ledger.balance(s.businesses[b].accountID)
            let health = Int(min(10_000, funds * 10_000 / max(1, payroll)))
            s.businesses[b].financialHealth = health
            if funds < max(10_000, payroll / 3) { s.businesses[b].stressDays += 1 } else { s.businesses[b].stressDays = max(0, s.businesses[b].stressDays - 1) }
            s.businesses[b].status = s.businesses[b].stressDays >= 5 ? .distressed : .active
            if s.businesses[b].stressDays >= 7 && s.day % 7 == 0,
               let h = s.households.firstIndex(where: { $0.employerID == s.businesses[b].id && $0.employment == .employed }) { dismiss(h, state: &s) }
            if s.businesses[b].stressDays >= 21 && funds < 10_000 { closeBusiness(b, state: &s) }
        }
        for i in s.households.indices {
            if s.households[i].employment == .employed && !s.businesses.contains(where: { $0.id == s.households[i].employerID && $0.status != .failed }) { dismiss(i, state: &s) }
            let h = s.households[i]
            if CrisisEngine.hiringAllowed(s) && h.employment == .unemployed && s.day % 7 == 0 && draw(0...99, household: i, channel: 2, state: &s) < 18 {
                let candidates = s.businesses.indices.filter { s.businesses[$0].status == .active && s.ledger.balance(s.businesses[$0].accountID) > max(h.monthlyIncome * 3, s.businesses[$0].payrollObligation * 2) }
                if !candidates.isEmpty {
                    let b = candidates[draw(0...(candidates.count - 1), household: i, channel: 3, state: &s)]
                    s.households[i].employment = .employed; s.households[i].employerID = s.businesses[b].id
                    s.businesses[b].employees.append(h.id)
                    s.journal.append(JournalEvent(day: s.day, entityID: h.id, message: "Rehired by \(s.businesses[b].id)"))
                }
            }
            let funds = s.ledger.balance(h.depositAccountID) + s.ledger.balance(h.cashAccountID)
            let liquidityStress = max(0, 10_000 - Int(min(10_000, funds * 10_000 / max(1, h.essentialDaily * 30))))
            let target = bounded(liquidityStress + (s.households[i].employment == .unemployed ? 2_000 : 0) + (s.households[i].defaulted ? 3_000 : 0))
            s.households[i].financialStress = bounded((s.households[i].financialStress * 3 + target) / 4)
            let targetConfidence = bounded(s.archetypeConfidence[h.archetypeID] - s.households[i].financialStress / 3 + (h.personalVariation - 10_000) / 4)
            s.households[i].confidence = bounded((h.confidence * 9 + targetConfidence) / 10)
            s.households[i].happiness = bounded((s.households[i].confidence + 10_000 - s.households[i].financialStress) / 2)
            if s.day % 7 == 0 && funds < h.essentialDaily * 3 && !s.households[i].defaulted && s.households[i].employment == .employed {
                _ = originate(borrowerID: h.id, accountID: h.depositAccountID, bankID: h.bankID, amount: h.essentialDaily * 20, state: &s)
            }
        }
    }
    private static func dismiss(_ i: Int, state s: inout SimulationState) {
        let h = s.households[i]
        if let b = s.businesses.firstIndex(where: { $0.id == h.employerID }) { s.businesses[b].employees.removeAll { $0 == h.id } }
        s.households[i].employment = .unemployed; s.households[i].employerID = nil
        s.journal.append(JournalEvent(day: s.day, entityID: h.id, message: "Employment ended"))
    }
    private static func closeBusiness(_ i: Int, state s: inout SimulationState) {
        s.businesses[i].status = .failed; s.businesses[i].financialHealth = 0
        for h in s.households.indices where s.households[h].employerID == s.businesses[i].id { dismiss(h, state: &s) }
        s.businesses[i].employees = []
        s.journal.append(JournalEvent(day: s.day, entityID: s.businesses[i].id, message: "Business closed; residual funds remain in estate"))
    }
    private static func bounded(_ value: Int) -> Int { max(0, min(10_000, value)) }
    private static func draw(_ range: ClosedRange<Int>, household: Int, channel: Int, state s: inout SimulationState) -> Int {
        guard let start = s.configuration.stableRandomFromDay, s.day >= start else { return s.random.integer(range) }
        // Counter-based streams align exogenous draws even when policy changes employment or choice-set sizes.
        let seed = s.configuration.seed ^ (UInt64(s.day) &* 0x9E3779B97F4A7C15) ^ (UInt64(household) &* 0xBF58476D1CE4E5B9) ^ (UInt64(channel) &* 0x94D049BB133111EB)
        var generator = SplitMix64(seed: seed)
        return generator.integer(range)
    }
}
