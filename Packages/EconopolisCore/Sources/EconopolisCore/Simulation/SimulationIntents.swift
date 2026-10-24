import Foundation

public enum EconomyQuestion: String, Sendable { case overview, employment, debt, banks, stress, spending, comparison, bankRun, district, businesses }
public enum SimulationIntent: Sendable {
    case query(EconomyQuestion, target: String?)
    case crisis(CrisisPlan)
    case policy(PolicyPlan)
    case unsupported(String)
    public var requiresConfirmation: Bool { switch self { case .crisis, .policy: true; default: false } }
}
public struct IntentContext: Sendable {
    public let eventOrdinal: Int
    public let day: Int
    public let policyRate: Int
    public let banks: [Bank]
    public let districts: [District]
    public init(update: SimulationUpdate) { eventOrdinal = update.scheduledEvents.count; day = update.metrics.day; policyRate = update.centralBank.annualRateBasisPoints; banks = update.banks; districts = update.districts }
}
public enum SimulationIntentParser {
    public static func parse(_ prompt: String, context: IntentContext) -> SimulationIntent {
        let q = prompt.lowercased().replacingOccurrences(of: ",", with: "")
        guard !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .unsupported("Enter a question or a scenario command.") }
        if q.range(of: "(?:^|\\s)-[0-9]", options: .regularExpression) != nil { return .unsupported("Use a positive magnitude and specify increase or decrease.") }
        let bank = context.banks.first { q.contains($0.id.lowercased()) || q.contains($0.name.lowercased()) } ?? context.banks.max { $0.depositLiabilities < $1.depositLiabilities }
        let district = context.districts.first { q.contains($0.name.lowercased()) || q.contains($0.id) }
        let duration = Int(number(q, pattern: "(?:for\\s+)?([0-9]+)\\s*days?") ?? 14)
        if q.contains("compare") { return .query(.comparison, target: nil) }
        if q.contains("explain") && q.contains("bank run") { return .query(.bankRun, target: bank?.id) }
        if q.contains("why"), let district { return .query(.district, target: district.id) }
        if q.contains("at risk") || q.contains("businesses at") { return .query(.businesses, target: district?.id) }
        if q.contains("emergency liquidity") || q.contains("rescue bank") {
            let amount = monetaryAmount(q) ?? (bank?.depositLiabilities ?? 0) / 2
            return .policy(PolicyPlan(id: "ai-liquidity-\(context.day + 1)-\(context.eventOrdinal)", kind: .liquidity, targetID: bank?.id, amount: amount, day: context.day + 1))
        }
        if q.contains("guarantee") { return .policy(PolicyPlan(id: "ai-guarantee-\(context.day + 1)-\(context.eventOrdinal)", kind: .guarantee, targetID: bank?.id, day: context.day + 1, duration: duration)) }
        if q.contains("relief") { return .policy(PolicyPlan(id: "ai-relief-\(context.day + 1)-\(context.eventOrdinal)", kind: .relief, targetID: district?.id, amount: monetaryAmount(q) ?? 10_000_000, day: context.day + 1)) }
        if q.contains("credit facility") { return .policy(PolicyPlan(id: "ai-facility-\(context.day + 1)-\(context.eventOrdinal)", kind: .businessCredit, targetID: district?.id, amount: monetaryAmount(q) ?? 10_000_000, day: context.day + 1)) }
        if q.contains("interest") && (q.contains("increase") || q.contains("decrease") || q.contains("raise") || q.contains("lower") || q.contains("set ")) {
            guard let value = number(q, pattern: "([0-9]+(?:\\.[0-9]+)?)\\s*(?:percentage points?|percent|%|basis points?)"), value <= 10_000 else { return .unsupported("Specify a rate change in percentage points or basis points, for example: Increase interest rates by 2 percentage points.") }
            let delta = Int(value * (q.contains("basis point") ? 1 : 100))
            let rate = q.contains("set ") ? delta : context.policyRate + ((q.contains("lower") || q.contains("decrease")) ? -delta : delta)
            return .policy(PolicyPlan(id: "ai-rate-\(context.day + 1)-\(context.eventOrdinal)", kind: .rate, day: context.day + 1, rateBasisPoints: rate))
        }
        var kind: CrisisKind?
        if q.contains("bank run") || q.contains("bank collaps") { kind = .bankRun }
        else if q.contains("recession") { kind = .recession }
        else if q.contains("layoff") || q.contains("lay off") { kind = .layoffs }
        else if q.contains("credit crunch") { kind = .creditCrunch }
        else if q.contains("payment") && q.contains("outage") { kind = .paymentOutage }
        if let kind {
            let percent = number(q, pattern: "([0-9]+(?:\\.[0-9]+)?)\\s*(?:percent|%)") ?? 75
            guard percent >= 0, percent <= 100 else { return .unsupported("Severity must be between 0 and 100 percent.") }
            let target = kind == .bankRun ? bank?.id : (district?.id ?? (kind == .paymentOutage || kind == .creditCrunch ? bank?.id : nil))
            return .crisis(CrisisPlan(id: "ai-\(kind.rawValue)-\(context.day + 1)-\(context.eventOrdinal)", kind: kind, targetID: target, severity: Int(percent * 100), startDay: context.day + 1, duration: duration))
        }
        if q.contains("unemploy") || q.contains("job") || q.contains("employ") { return .query(.employment, target: nil) }
        if q.contains("debt") || q.contains("loan") { return .query(.debt, target: nil) }
        if q.contains("bank") || q.contains("rate") { return .query(.banks, target: bank?.id) }
        if q.contains("stress") || q.contains("confidence") { return .query(.stress, target: district?.id) }
        if q.contains("spend") || q.contains("money") { return .query(.spending, target: nil) }
        if q.contains("econom") || q.contains("happening") { return .query(.overview, target: nil) }
        return .unsupported("Supported offline: bank runs, recession, layoffs, credit crunch, payment outage, policy rates, emergency liquidity, guarantees, relief, credit facilities, and questions about recorded economic metrics.")
    }
    private static func number(_ text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        for group in 1..<match.numberOfRanges { if let range = Range(match.range(at: group), in: text), let result = Double(text[range]) { return result } }
        return nil
    }
    private static func monetaryAmount(_ text: String) -> Money? {
        guard let value = number(text, pattern: "\\$\\s*([0-9]+(?:\\.[0-9]+)?)|(?:amount|provide|issue|inject|relief|facility)\\s+(?:of\\s+)?([0-9]+(?:\\.[0-9]+)?)") ?? number(text, pattern: "([0-9]+(?:\\.[0-9]+)?)\\s*(?:million|thousand|dollars)") else { return nil }
        let factor = text.contains("million") ? 1_000_000.0 : (text.contains("thousand") ? 1_000 : 1)
        let cents = value * factor * 100
        guard cents.isFinite, cents >= 0, cents <= 1_000_000_000 else { return -1 }
        return Money(cents.rounded())
    }
}
public enum SimulationCommandValidator {
    public static func validate(_ intent: SimulationIntent, context: IntentContext) throws {
        switch intent {
        case .crisis(let plan):
            try plan.validate()
            guard plan.startDay > context.day else { throw SimulationError.invalidConfiguration }
            if plan.kind == .bankRun { guard context.banks.contains(where: { $0.id == plan.targetID }) else { throw SimulationError.invalidConfiguration } }
        case .policy(let policy):
            try policy.validate(); guard policy.day > context.day else { throw SimulationError.invalidConfiguration }
            if policy.kind == .liquidity || policy.kind == .guarantee { guard context.banks.contains(where: { $0.id == policy.targetID }) else { throw SimulationError.invalidConfiguration } }
        case .query, .unsupported: break
        }
    }
}
public protocol AIModelProvider: Sendable { func interpret(_ prompt: String, context: IntentContext) async throws -> SimulationIntent }
public struct OfflineEconomistProvider: AIModelProvider {
    public init() {}
    public func interpret(_ prompt: String, context: IntentContext) async throws -> SimulationIntent { SimulationIntentParser.parse(prompt, context: context) }
}
public enum EconomicExplanationService {
    public static func explain(_ question: EconomyQuestion, update: SimulationUpdate, entities: WorldEntities, other: SimulationUpdate?) -> String {
        let m = update.metrics
        func money(_ amount: Money) -> String { (Double(amount) / 100).formatted(.currency(code: "USD").precision(.fractionLength(2))) }
        func percent(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(1))) + "%" }
        let source = "Recorded state, day \(m.day). "
        switch question {
        case .employment: return source + "\(m.employed) of \(m.laborForce) labor-force citizens are employed; unemployment is \(percent(m.unemploymentPercentage)). Students and retirees are outside the labor force."
        case .debt: return source + "Households owe \(money(m.aggregateHouseholdDebt)); \(m.householdDefaults) have defaulted. Debt includes written-off borrower obligations."
        case .banks: return source + "Bank funding/settlement stress averages \(percent(m.bankLiquidityStress)). The policy rate is \(percent(Double(update.centralBank.annualRateBasisPoints) / 100)). Reserve assets are distinct from deposit liabilities."
        case .stress, .district: return source + "Confidence averages \(percent(m.averageConfidence)); system stress is \(percent(m.financialStress)). Use district inspectors for the selected area's actual employment, seller spending and business health. Only recorded causal events establish why a particular entity was affected."
        case .spending: return source + "Consumer spending today was \(money(m.consumerSpending)); settled transfer volume was \(money(m.transactionVolume)), including financial flows. Neither is official GDP."
        case .comparison:
            guard let other, other.metrics.day == m.day else { return source + "Replay both branches to the same day before comparing outcomes." }
            return source + "This world has \(m.employed - other.metrics.employed) more employed citizens, \(m.activeBusinesses - other.metrics.activeBusinesses) more active firms, and \(money(m.consumerSpending - other.metrics.consumerSpending)) greater spending than the other world. Outstanding emergency claims are \(money(update.crisis?.emergencyClaims ?? 0)). Higher liquidity is not automatically a reduction in loss."
        case .bankRun:
            guard let crisis = update.crisis else { return source + "No bank run has been recorded in this world. Start the live demo or confirm a crisis preview to calculate one." }
            return source + "Depositors requested \(money(crisis.requestedWithdrawals)) of cumulative cash conversions; \(money(crisis.settledWithdrawals)) settled and \(money(crisis.unmetWithdrawals)) did not settle at the time requested. These are attempted flows, not destroyed deposits. Outstanding public liquidity claims are \(money(crisis.emergencyClaims)). The latest recorded consequence is: \(crisis.records.last?.message ?? "No consequence recorded")."
        case .businesses:
            let atRisk = entities.businesses.filter { $0.status != .active || $0.financialHealth < 3_000 }
            return source + "\(atRisk.count) firms are distressed, failed or have less than 30% modeled payroll liquidity coverage. Examples: \(atRisk.prefix(4).map(\.name).joined(separator: ", ")). This is a cash-flow measure, not a forecast."
        case .overview: return source + "\(m.population) citizens, \(m.activeBusinesses) active firms, \(percent(m.unemploymentPercentage)) unemployment and \(money(m.consumerSpending)) spending today. All values come from the ledger and derived state."
        }
    }
}
