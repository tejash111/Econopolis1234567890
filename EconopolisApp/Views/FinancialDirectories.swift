import EconopolisCore
import SwiftUI

enum DirectoryKind: String, CaseIterable, Identifiable {
  case banks = "Banks"
  case businesses = "Businesses"
  case districts = "Districts"
  case information = "Economy information"
  case settings = "Settings"
  var id: String { rawValue }
}
struct InstitutionDirectory: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var model: SimulationViewModel
  var category: DirectoryKind? = nil
  @State private var search = ""
  @State private var industry = ""
  @State private var district = ""
  var body: some View {
    List {
      if category == nil {
        Section("Explore") {
          ForEach(DirectoryKind.allCases) { kind in
            NavigationLink(kind.rawValue) { directory(kind) }
          }
        }
      }
      if category == nil || category == .banks {
        Section("Banks") {
          ForEach((model.update?.banks ?? []).filter { matches($0.name, $0.id) }) { bank in
            NavigationLink(value: bank.id) {
              VStack(alignment: .leading, spacing: 5) {
                Text(bank.name).font(.headline)
                Text(
                  "\(bank.customers.count) customers · \(bank.status.rawValue) · stress \(bank.stress / 100)%"
                ).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
          if category == nil {
            NavigationLink("Municipal Treasury", value: "treasury")
            NavigationLink("Central Bank", value: "central-bank")
          }
        }
      }
      if category == .businesses {
        Section("Filters") {
          Picker("Industry", selection: $industry) {
            Text("All industries").tag("")
            ForEach(Industry.allCases, id: \.rawValue) {
              Text($0.rawValue.capitalized).tag($0.rawValue)
            }
          }
          Picker("District", selection: $district) {
            Text("All districts").tag("")
            ForEach(model.update?.districts ?? []) { Text($0.name).tag($0.id) }
          }
        }
      }
      if category == nil || category == .businesses {
        Section("Businesses") {
          ForEach(
            (model.entities?.businesses ?? []).filter {
              matches($0.name, $0.id) && (industry.isEmpty || $0.industry.rawValue == industry)
                && (district.isEmpty || $0.districtID == district)
            }
          ) { business in
            NavigationLink(value: business.id) {
              VStack(alignment: .leading, spacing: 4) {
                Text(business.name)
                Text("\(business.employees.count) employees · \(business.status.rawValue)").font(
                  .caption
                ).foregroundStyle(.secondary)
              }
            }
          }
        }
      }
      if category == nil || category == .districts {
        Section("Districts") {
          ForEach((model.update?.districts ?? []).filter { matches($0.name, $0.id) }) {
            NavigationLink($0.name, value: $0.id)
          }
        }
      }
      if category == nil && !search.isEmpty {
        Section("Citizens") {
          ForEach((model.entities?.citizens ?? []).filter { matches($0.name, $0.id) }.prefix(50)) {
            NavigationLink($0.name, value: $0.id)
          }
        }
      }
    }.navigationTitle(category?.rawValue ?? "City directory").navigationBarTitleDisplayMode(.inline)
      .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
      .navigationDestination(for: String.self) { id in
        EntityInspector(
          model: model, id: id,
          locate: { target in
            model.preferences.focus(target)
            dismiss()
          })
      }
  }
  private func matches(_ name: String, _ id: String) -> Bool {
    search.isEmpty || name.localizedCaseInsensitiveContains(search)
      || id.localizedCaseInsensitiveContains(search)
  }
  @ViewBuilder private func directory(_ kind: DirectoryKind) -> some View {
    switch kind {
    case .settings: SettingsScreen(model: model)
    case .information: EconomyInformation(model: model)
    default: InstitutionDirectory(model: model, category: kind)
    }
  }
}
struct SettingsScreen: View {
  @Bindable var model: SimulationViewModel
  @State private var reports: [URL] = []
  @State private var exporting = false
  @State private var exportError: String?
  var body: some View {
    Form {
      Section("Appearance") {
        Picker("Theme", selection: $model.preferences.appearance) {
          ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) }
        }
        Toggle("Haptic feedback", isOn: $model.preferences.haptics)
      }
      Section("City rendering") {
        Picker("Graphics quality", selection: $model.preferences.quality) {
          ForEach(GraphicsQuality.allCases) { Text($0.rawValue).tag($0) }
        }
        Toggle("Actual transaction flows", isOn: $model.preferences.flows)
        Toggle("Isometric fallback", isOn: $model.use2D)
        Text(
          "Quality limits density markers and concurrent flows. Home/work markers represent district aggregates, not calculated physical journeys."
        ).font(.caption)
      }
      Section("Measured renderer diagnostics") {
        LabeledContent(
          "Logical buildings + markers", value: "\(model.preferences.renderEntityCount)")
        LabeledContent(
          "Last scene update",
          value: model.preferences.lastRenderUpdateMS.formatted(
            .number.precision(.fractionLength(2))) + " ms")
        Text(
          "CPU update wall time, not GPU FPS. Real-device frame pacing and battery use are not measured."
        ).font(.caption)
      }
      Section("Local session") {
        Text(model.persistenceMessage).font(.caption)
        Button("Save and pause") { model.pause() }
        Text("No account, network connection, or financial information required.").font(.caption)
      }
      Section("Export recorded data") {
        Button("Prepare CSV / JSON reports") {
          exporting = true
          Task {
            defer { exporting = false }
            do {
              reports = try await model.exportReports()
              exportError = nil
            } catch { exportError = error.localizedDescription }
          }
        }.disabled(exporting || model.isBusy)
        if exporting { ProgressView() }
        ForEach(reports, id: \.self) { url in
          ShareLink(item: url) { Label(url.lastPathComponent, systemImage: "square.and.arrow.up") }
        }
        if let exportError { Text(exportError).font(.caption).foregroundStyle(.orange) }
      }
    }.navigationTitle("Settings")
  }
}
struct EconomyInformation: View {
  let model: SimulationViewModel
  var body: some View {
    List {
      Section("Synthetic financial city") {
        Text(
          "ECONOPOLIS is an educational, deterministic mechanism model. It does not predict actual markets, banks or policy outcomes."
        )
        LabeledContent("Seed", value: String(model.update?.seed ?? 0))
        LabeledContent("Citizens", value: "\(model.update?.metrics.population ?? 0)")
        LabeledContent("Businesses", value: "\(model.entities?.businesses.count ?? 0)")
        LabeledContent("Banks", value: "\(model.update?.banks.count ?? 0)")
      }
      Section("Money and banks") {
        Text(
          "Integer cents, fully backed custody deposits and funded loans. Reserves, deposit liabilities, credit claims and equity remain distinct. Public liquidity creates a recorded claim and a repayable bank obligation. No regulatory capital or GDP claims are made."
        )
      }
      Section("Behavior") {
        Text(
          "Archetype tendencies and deterministic personal variation drive actual spending, employment, payroll, loan servicing and confidence. Consumer spending is an activity proxy; transaction volume also includes financial flows."
        )
      }
      Section("Visual abstractions") {
        Text(
          "Residential buildings group real residents by district. Dots show home/work density; no GPS routes are calculated. Cyan particles represent a bounded sample of posted transfers, using district anchors for citizen accounts."
        )
      }
    }.navigationTitle("Economy information").navigationBarTitleDisplayMode(.inline)
  }
}
struct TransactionRow: View {
  let transaction: EconopolisCore.Transaction
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(transaction.kind.rawValue.capitalized).font(.subheadline)
        Text("Day \(transaction.day) · #\(transaction.id)").font(.caption).foregroundStyle(
          .secondary)
      }
      Spacer()
      Text(money(transaction.amount)).font(.subheadline.monospacedDigit())
    }.padding(.vertical, 4).accessibilityElement(children: .combine)
  }
}
struct TransactionInspector: View {
  let transaction: EconopolisCore.Transaction
  let model: SimulationViewModel
  var body: some View {
    List {
      Section("Posted ledger transfer") {
        LabeledContent("Amount", value: money(transaction.amount))
        LabeledContent("Day", value: "\(transaction.day)")
        LabeledContent("Kind", value: transaction.kind.rawValue)
        LabeledContent("Status", value: transaction.settled ? "Settled" : "Rejected")
        LabeledContent("Sender account", value: transaction.sender)
        LabeledContent("Recipient account", value: transaction.recipient)
      }
      Section("Economic entities") {
        if let id = model.entities?.accountOwners[transaction.sender] {
          NavigationLink("Sender: \(id)") { EntityInspector(model: model, id: id) }
        }
        if let id = model.entities?.accountOwners[transaction.recipient] {
          NavigationLink("Recipient: \(id)") { EntityInspector(model: model, id: id) }
        }
      }
    }.navigationTitle("Transaction #\(transaction.id)").navigationBarTitleDisplayMode(.inline)
  }
}
struct ActivityFeed: View {
  let model: SimulationViewModel
  var body: some View {
    List {
      if let transactions = model.update?.recentTransactions, !transactions.isEmpty {
        ForEach(transactions) { tx in
          NavigationLink {
            TransactionInspector(transaction: tx, model: model)
          } label: {
            TransactionRow(transaction: tx)
          }
        }
      } else {
        EmptyFinancialState(
          title: "No settled activity yet",
          detail: "Advance the simulation to record actual transfers.")
      }
      Section {
        Text(
          "\(model.update?.rejectedCount ?? 0) rejected attempts are recorded separately; they are never animated as successful payments."
        ).font(.caption)
      }
    }.navigationTitle("Financial activity").navigationBarTitleDisplayMode(.inline)
  }
}
