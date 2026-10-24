import EconopolisCore
import SwiftUI

struct CrisisScreen: View {
  @Bindable var model: SimulationViewModel
  @State private var crisis: CrisisPlan?
  @State private var policy: PolicyPlan?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("One economy.\nTwo possible futures.").font(.title.bold())
        Text(
          "Crises affect real payments, jobs, credit and spending. Policies are previews until you confirm."
        ).font(.subheadline).foregroundStyle(.secondary)
        demo
        WorldPicker(model: model)
        if model.isBusy { ProgressView("Computing both economies…").font(.subheadline) }
        TimelinePanel(model: model)
        if model.demoStage >= 2 { ComparisonPanel(model: model) }
        Text("Choose a crisis").font(.title3.bold())
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
          ForEach(CrisisKind.allCases) { kind in
            Button {
              crisis = CrisisPlan(
                id:
                  "crisis-\((model.update?.metrics.day ?? 0) + 1)-\(model.update?.scheduledEvents.count ?? 0)",
                kind: kind, targetID: kind == .bankRun ? model.update?.banks.first?.id : nil,
                startDay: (model.update?.metrics.day ?? 0) + 1)
            } label: {
              VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol(kind)).font(.title2).foregroundStyle(.orange)
                Text(kind.rawValue).font(.subheadline.bold()).multilineTextAlignment(.leading)
              }.frame(maxWidth: .infinity, minHeight: 86, alignment: .leading).padding(14)
                .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 18))
            }.buttonStyle(.plain).disabled(model.isBusy)
          }
        }
        Text("Intervene in World B").font(.title3.bold())
        ForEach(PolicyKind.allCases) { kind in
          Button {
            policy = PolicyPlan(
              id:
                "policy-\((model.branches?.b.metrics.day ?? 0) + 1)-\(model.branches?.b.scheduledEvents.count ?? 0)",
              kind: kind,
              targetID: kind == .liquidity || kind == .guarantee
                ? model.update?.banks.first?.id : nil, day: (model.branches?.b.metrics.day ?? 0) + 1
            )
          } label: {
            HStack {
              Label(kind.rawValue, systemImage: "building.columns")
              Spacer()
              Image(systemName: "chevron.right")
            }.frame(minHeight: 48).contentShape(Rectangle())
          }.buttonStyle(.plain).disabled(model.isBusy)
        }
        if let events = model.update?.scheduledEvents, !events.isEmpty {
          Text("Scheduled commands").font(.headline)
          ForEach(events) { event in
            Text("Day \(event.day) · \(event.id)").font(.caption).foregroundStyle(.secondary)
          }
        }
        if let records = model.update?.crisis?.records.suffix(12).reversed(), !records.isEmpty {
          Text("Recorded consequences").font(.title3.bold())
          ForEach(Array(records)) { item in
            VStack(alignment: .leading, spacing: 4) {
              Text(item.message).font(.subheadline)
              Text(
                "Day \(item.day) · \(item.entityID)"
                  + (item.transactionID.map { " · transaction #\($0)" } ?? "")
              ).font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 5)
          }
        }
        Text(
          "A synthetic mechanism model, not a real-world forecast. Settlement resolution is distinct from insolvency. A rescue may improve settlement capacity without reducing debt or eliminating fiscal risk."
        ).font(.caption).foregroundStyle(.secondary)
      }.padding(18)
    }.background(Color.cityNight).navigationTitle("Crisis Lab").navigationBarTitleDisplayMode(
      .inline
    )
    .sheet(item: $crisis) { plan in CrisisEditor(model: model, initial: plan) }
    .sheet(item: $policy) { plan in PolicyEditor(model: model, initial: plan) }
  }
  private var demo: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("THE GREAT BANK RUN", systemImage: "play.rectangle.fill").font(.headline)
        .foregroundStyle(.cyan)
      Text(
        [
          "Start with a repeatable, living economy.",
          "The city is at day 7. Explore it, then trigger the same run in both worlds.",
          "The unassisted future is recorded. Could we have prevented this?",
          "World B is back at the pre-crisis snapshot. World A retains its recorded future.",
          "Compare the same crisis with and without a repayable central-bank advance.",
        ][min(4, model.demoStage)]
      ).font(.subheadline)
      Button {
        if model.demoStage == 0 { model.startDemo() } else { model.nextDemo() }
      } label: {
        Text(
          [
            "START LIVE DEMO", "Trigger The Great Bank Run", "Rewind World B",
            "Apply liquidity & replay", "Restart live demo",
          ][min(4, model.demoStage)]
        ).font(.headline).frame(maxWidth: .infinity, minHeight: 44)
      }.buttonStyle(.borderedProminent).tint(.cyan).disabled(model.isBusy).accessibilityIdentifier(
        "demoNext")
    }.padding(18).economicGlass()
  }
  private func symbol(_ kind: CrisisKind) -> String {
    switch kind {
    case .bankRun: "building.columns.fill"
    case .interestRate: "percent"
    case .layoffs: "person.2.slash"
    case .recession: "chart.line.downtrend.xyaxis"
    case .creditCrunch: "lock.shield"
    case .paymentOutage: "network.slash"
    }
  }
}
struct CrisisEditor: View {
  @Environment(\.dismiss) private var dismiss
  let model: SimulationViewModel
  let initial: CrisisPlan
  @State private var severity = 75.0
  @State private var duration = 14.0
  @State private var rate = 12.0
  @State private var target = ""
  var body: some View {
    NavigationStack {
      Form {
        Section(initial.kind.rawValue) {
          Text(
            "Applies to both worlds on day \(initial.startDay). No effects occur until confirmation and day advancement."
          ).font(.subheadline)
          if [.bankRun, .creditCrunch, .paymentOutage, .layoffs].contains(initial.kind) {
            Picker("Target", selection: $target) {
              if initial.kind != .bankRun { Text("Whole economy").tag("") }
              if initial.kind != .layoffs {
                ForEach(model.update?.banks ?? []) { Text($0.name).tag($0.id) }
              }
              if initial.kind == .layoffs || initial.kind == .paymentOutage {
                ForEach(model.update?.districts ?? []) { Text($0.name).tag($0.id) }
              }
              if initial.kind == .layoffs {
                ForEach(Industry.allCases, id: \.self) {
                  Text($0.rawValue.capitalized).tag($0.rawValue)
                }
              }
            }
          }
          LabeledContent("Severity", value: "\(Int(severity))%")
          Slider(value: $severity, in: 10...100, step: 5).accessibilityLabel("Crisis severity")
          LabeledContent("Duration", value: "\(Int(duration)) days")
          Slider(value: $duration, in: 1...60, step: 1).accessibilityLabel("Crisis duration")
          if initial.kind == .interestRate {
            LabeledContent("Variable loan policy rate", value: percent(rate))
            Slider(value: $rate, in: 0...30, step: 0.25)
          }
        }
        Section("Model limits") {
          Text(
            "Bank runs constrain the daily cash-conversion window of fully backed custody deposits. Cash remains spendable. Five consecutive days of unmet requests can trigger settlement resolution; no deposit principal is destroyed. Outages queue payroll and benefits while loan obligations retry after recovery."
          ).font(.caption)
        }
        Button("Confirm crisis") {
          var plan = initial
          plan.severity = Int(severity * 100)
          plan.duration = Int(duration)
          plan.rateBasisPoints = Int(rate * 100)
          plan.targetID = target.isEmpty ? nil : target
          model.schedule(plan)
          dismiss()
        }.disabled(model.isBusy)
      }.navigationTitle("Preview crisis").navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }
    }.onAppear {
      target = initial.targetID ?? ""
      severity = Double(initial.severity) / 100
      duration = Double(initial.duration)
      rate = Double(initial.rateBasisPoints) / 100
    }
  }
}
struct PolicyEditor: View {
  @Environment(\.dismiss) private var dismiss
  let model: SimulationViewModel
  let initial: PolicyPlan
  @State private var amountText = "1000000"
  @State private var rate = 4.0
  @State private var days = 30.0
  @State private var target = ""
  var body: some View {
    NavigationStack {
      Form {
        Section(initial.kind.rawValue) {
          Text(
            "World B · day \(initial.day). Confirming schedules this policy; opening this screen does not spend funds."
          )
          if initial.kind == .liquidity || initial.kind == .guarantee {
            Picker("Bank", selection: $target) {
              ForEach(model.update?.banks ?? []) { Text($0.name).tag($0.id) }
            }
          } else if initial.kind == .relief || initial.kind == .businessCredit {
            Picker("District", selection: $target) {
              Text("All eligible").tag("")
              ForEach(model.update?.districts ?? []) { Text($0.name).tag($0.id) }
            }
          }
          if initial.kind != .guarantee && initial.kind != .rate {
            TextField("Budget in fictional dollars", text: $amountText).keyboardType(.decimalPad)
            Text("\(money(MoneyInput.cents(amountText) ?? 0)) maximum").font(.caption)
          }
          if initial.kind == .rate || initial.kind == .liquidity || initial.kind == .businessCredit
          {
            LabeledContent("Annual rate", value: percent(rate))
            Slider(value: $rate, in: 0...30, step: 0.25)
          }
          if initial.kind == .guarantee {
            LabeledContent("Duration", value: "\(Int(days)) days")
            Slider(value: $days, in: 1...90, step: 1)
          }
        }
        Section("Funding and obligations") {
          Text(
            initial.kind == .liquidity
              ? "The central bank issues reserves against a repayable claim. Principal amortizes monthly; interest is remitted to the treasury. This is a liability, not money saved."
              : (initial.kind == .guarantee
                ? "Assurance reduces modeled withdrawal demand for the selected term. It does not transfer money or insure a real bank."
                : "Relief and business credit use existing treasury funds. If funding or eligible recipients are unavailable, settlement may be lower than this budget. Business loans must be repaid.")
          ).font(.subheadline)
        }
        Button("Confirm policy in World B") {
          var plan = initial
          plan.amount = MoneyInput.cents(amountText) ?? 0
          plan.rateBasisPoints = Int(rate * 100)
          plan.duration = Int(days)
          plan.targetID = target.isEmpty ? nil : target
          model.apply(plan)
          dismiss()
        }.disabled(model.isBusy || (MoneyInput.cents(amountText) ?? 0) <= 0)
      }.navigationTitle("Preview intervention").navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }
    }.onAppear {
      target = initial.targetID ?? ""
      amountText = MoneyInput.dollars(initial.amount)
      rate = Double(initial.rateBasisPoints) / 100
      days = Double(initial.duration)
    }
  }
}
struct TimelinePanel: View {
  @Bindable var model: SimulationViewModel
  @State private var day = 0.0
  @State private var scrubbing = false
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("Timeline", systemImage: "clock.arrow.circlepath").font(.headline)
        Spacer()
        Text("Day \(model.update?.metrics.day ?? 0)").monospacedDigit().font(.caption)
      }
      Slider(value: $day, in: 0...Double(max(1, model.branches?.furthestDay ?? 1)), step: 1) {
        editing in
        scrubbing = editing
        if editing { model.pause() } else { model.seek(Int(day)) }
      }.disabled(model.isBusy || (model.branches?.furthestDay ?? 0) == 0).accessibilityLabel(
        "Simulation timeline")
      Text("Replays actual state and scheduled commands. Branches retain separate policies.").font(
        .caption
      ).foregroundStyle(.secondary)
    }.padding(14).background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 18)).onChange(
      of: model.update?.metrics.day, initial: true
    ) { _, value in if !scrubbing { day = Double(value ?? 0) } }
  }
}
struct ComparisonPanel: View {
  let model: SimulationViewModel
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Computed futures").font(.title3.bold())
      if let branches = model.branches {
        if branches.a.metrics.day != branches.b.metrics.day {
          Text(
            "A: recorded day \(branches.a.metrics.day). B: restored day \(branches.b.metrics.day). Replay B before comparing equal horizons."
          ).font(.subheadline).foregroundStyle(.orange)
        } else {
          HStack {
            Text("Metric")
            Spacer()
            Text("World A").frame(width: 88)
            Text("World B").frame(width: 88)
          }.font(.caption.bold())
          comparison("Employed", "\(branches.a.metrics.employed)", "\(branches.b.metrics.employed)")
          comparison(
            "Active firms", "\(branches.a.metrics.activeBusinesses)",
            "\(branches.b.metrics.activeBusinesses)")
          comparison(
            "Stress", percent(branches.a.metrics.financialStress),
            percent(branches.b.metrics.financialStress))
          comparison(
            "Defaults", "\(branches.a.metrics.householdDefaults)",
            "\(branches.b.metrics.householdDefaults)")
          comparison(
            "Unmet withdrawals", compactMoney(branches.a.crisis?.unmetWithdrawals ?? 0),
            compactMoney(branches.b.crisis?.unmetWithdrawals ?? 0))
          comparison(
            "CB claims owed", compactMoney(branches.a.crisis?.emergencyClaims ?? 0),
            compactMoney(branches.b.crisis?.emergencyClaims ?? 0))
          comparison(
            "Fiscal outflow", compactMoney(branches.a.crisis?.fiscalCost ?? 0),
            compactMoney(branches.b.crisis?.fiscalCost ?? 0))
          Text(
            "Unmet withdrawals are cumulative attempted flows, not destroyed deposits. Central-bank claims are outstanding stocks."
          ).font(.caption).foregroundStyle(.secondary)
        }
      }
    }.padding(16).background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 20))
  }
  private func comparison(_ title: String, _ a: String, _ b: String) -> some View {
    HStack {
      Text(title).lineLimit(2)
      Spacer()
      Text(a).frame(width: 88, alignment: .trailing)
      Text(b).frame(width: 88, alignment: .trailing)
    }.font(.caption.monospacedDigit()).padding(.vertical, 3)
  }
}
