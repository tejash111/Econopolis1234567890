import EconopolisCore
import SwiftUI

struct CitizenFilter: Equatable {
  var query = "", district = "", employment = "", archetype = ""
  func apply(_ citizens: [CitizenSummary]) -> [CitizenSummary] {
    citizens.filter { citizen in
      (query.isEmpty || citizen.name.localizedCaseInsensitiveContains(query)
        || citizen.id.localizedCaseInsensitiveContains(query))
        && (district.isEmpty || citizen.districtID == district)
        && (employment.isEmpty || citizen.employment.rawValue == employment)
        && (archetype.isEmpty || citizen.archetype == archetype)
    }
  }
}
struct CitizensScreen: View {
  @Bindable var model: SimulationViewModel
  let select: (String) -> Void
  @State private var filter = CitizenFilter()
  @State private var filters = false
  @State private var joining = false
  @FocusState private var searchFocused: Bool
  private var citizens: [CitizenSummary] { filter.apply(model.entities?.citizens ?? []) }
  var body: some View {
    List {
      Section { WorldPicker(model: model) }
      if let player = model.update?.playerID {
        Section { Button("Open your fictional citizen") { select(player) } }
      }
      if citizens.isEmpty {
        EmptyFinancialState(title: "No matching citizens", detail: "Change the search or filters.")
        Button("Clear filters") { filter = CitizenFilter() }
      }
      Section("\(citizens.count.formatted()) citizens") {
        ForEach(citizens) { citizen in
          Button {
            searchFocused = false
            select(citizen.id)
          } label: {
            HStack(spacing: 12) {
              Text(String(citizen.name.prefix(1))).font(.headline).foregroundStyle(.blue).frame(
                width: 38, height: 38
              ).background(.blue.opacity(0.1), in: Circle())
              VStack(alignment: .leading, spacing: 4) {
                Text(citizen.name).font(.subheadline.bold())
                Text(citizen.archetype + " · " + citizen.employment.rawValue).font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer(minLength: 4)
              VStack(alignment: .trailing, spacing: 4) {
                Text(compactMoney(citizen.balance + citizen.cash)).font(
                  .subheadline.monospacedDigit())
                Text("Stress \(citizen.stress / 100)%").font(.caption2).foregroundStyle(
                  citizen.stress > 6_000 ? .orange : .secondary)
              }
            }.padding(.vertical, 6).contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityElement(children: .combine)
        }
      }
    }.scrollContentBackground(.hidden).background(Color.appBackground).navigationTitle("Citizens")
      .searchable(
        text: $filter.query, placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Name or citizen ID"
      ).searchFocused($searchFocused)
      .onSubmit(of: .search) { searchFocused = false }
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { searchFocused = false }
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            filters = true
          } label: {
            Image(systemName: "line.3.horizontal.decrease")
          }.accessibilityLabel("Citizen filters")
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            joining = true
          } label: {
            Image(systemName: "person.badge.plus")
          }.accessibilityLabel("Join the Economy")
        }
      }
      .sheet(isPresented: $joining) { JoinEconomyScreen(model: model) }
      .sheet(isPresented: $filters) {
        NavigationStack {
          Form {
            Picker("District", selection: $filter.district) {
              Text("All districts").tag("")
              ForEach(model.update?.districts ?? []) { Text($0.name).tag($0.id) }
            }
            Picker("Employment", selection: $filter.employment) {
              Text("All statuses").tag("")
              ForEach(["employed", "unemployed", "student", "retired"], id: \.self) {
                Text($0.capitalized).tag($0)
              }
            }
            Picker("Archetype", selection: $filter.archetype) {
              Text("All archetypes").tag("")
              ForEach(
                Array(Set(model.entities?.citizens.map(\.archetype) ?? [])).sorted(), id: \.self
              ) { Text($0).tag($0) }
            }
            Button("Clear all filters") { filter = CitizenFilter() }
          }.navigationTitle("Filter citizens").toolbar { Button("Done") { filters = false } }
        }.presentationDetents([.medium, .large])
      }
  }
}
struct EntityInspector: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var model: SimulationViewModel
  let id: String
  var locate: ((String) -> Void)? = nil
  @State private var evidence: EntityEvidence?
  @State private var queryError: String?
  private var entityName: String {
    model.entities?.citizens.first { $0.id == id }?.name ?? model.entities?.businesses.first {
      $0.id == id
    }?.name ?? model.update?.banks.first { $0.id == id }?.name ?? model.update?.districts.first {
      $0.id == id
    }?.name ?? id
  }
  var body: some View {
    List {
      Section { WorldPicker(model: model) }
      if let citizen = model.entities?.citizens.first(where: { $0.id == id }) {
        Section("Overview") {
          row("Citizen ID", citizen.id)
          row("Archetype", citizen.archetype)
          row("Employment", citizen.employment.rawValue.capitalized)
          relation("District", citizen.districtID)
          if let employer = citizen.employerID { relation("Employer", employer) }
          relation("Bank", citizen.bankID)
        }
        Section("Finances") {
          row("Reference monthly income", money(citizen.income))
          row("Deposits", money(citizen.balance))
          row("Cash", money(citizen.cash))
          row("Debt", money(citizen.debt))
          row("Confidence", percent(Double(citizen.confidence) / 100))
          row("Financial stress", percent(Double(citizen.stress) / 100))
        }
        if let other = model.otherEntities?.citizens.first(where: { $0.id == id }) {
          Section("Same citizen · other world") {
            row("Employment", other.employment.rawValue.capitalized)
            row("Deposits + cash", money(other.balance + other.cash))
            row("Debt", money(other.debt))
            row("Stress", percent(Double(other.stress) / 100))
            row(
              "Liquidity difference",
              money(citizen.balance + citizen.cash - other.balance - other.cash))
          }
        }
        if let decisions = evidence?.household?.decisions.suffix(7).reversed(), !decisions.isEmpty {
          Section("Actual recent decisions") {
            ForEach(Array(decisions), id: \.day) { decision in
              VStack(alignment: .leading, spacing: 4) {
                Text("Day \(decision.day) · spent \(money(decision.spending))").font(.subheadline)
                Text(decision.reason).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
        }
        Section {
          Text(
            "Locations are home/work district abstractions. Personal daily balance history is not recorded; the timeline shows actual decisions and events."
          ).font(.caption)
        }
      } else if let business = model.entities?.businesses.first(where: { $0.id == id }) {
        Section("Business") {
          row("Industry", business.industry.rawValue.capitalized)
          relation("District", business.districtID)
          relation("Bank", business.bankID)
          row("Status", business.status.rawValue.capitalized)
          row("Employees", "\(business.employees.count)")
          row("Operating funds", money(business.operatingBalance))
          row("Revenue today", money(business.revenue))
          row("Expenses today", money(business.expenses))
          row("Profit / loss today", money(business.profit))
          row("Monthly payroll", money(business.payrollObligation))
          row("Credit exposure", money(business.creditExposure))
        }
        if let other = model.otherEntities?.businesses.first(where: { $0.id == id }) {
          Section("Other world") {
            row("Employees", "\(other.employees.count)")
            row("Operating funds", money(other.operatingBalance))
            row("Difference", money(business.operatingBalance - other.operatingBalance))
          }
        }
        locateButton(id)
      } else if let bank = model.update?.banks.first(where: { $0.id == id }) {
        Section("Commercial bank") {
          row("Customers", "\(bank.customers.count)")
          row("Status", bank.status.rawValue.capitalized)
          row("Reserve assets", money(bank.reserves))
          row("Custody deposit liabilities", money(bank.depositLiabilities))
          row("Unencumbered liquidity", money(bank.reserves - bank.depositLiabilities))
          row("Performing loan claims", money(bank.performingLoanAssets))
          row("Book equity", money(bank.equity))
          row("Funding / settlement stress", percent(Double(bank.stress) / 100))
        }
        let debt =
          model.update?.crisis?.publicLoans.filter { $0.borrowerID == bank.id && $0.centralBank }
          .reduce(Money(0)) { $0 + $1.outstanding } ?? 0
        Section("Public funding") {
          row("Central-bank debt", money(debt))
          Text(
            "Reserve assets + performing loans = deposits + equity + central-bank obligations. These are simplified book positions, not regulatory capital ratios."
          ).font(.caption)
        }
        locateButton(id)
      } else if let district = model.update?.districts.first(where: { $0.id == id }),
        let index = model.city?.districts.firstIndex(where: { $0.id == id })
      {
        let activity = model.update?.metrics.districts.first { $0.id == id }
        Section(district.name) {
          row("Population", "\(activity?.population ?? 0)")
          row("Employed residents", "\(activity?.employed ?? 0)")
          row("Active businesses", "\(activity?.activeBusinesses ?? 0)")
          row("Spending today", money(activity?.consumerSpending ?? 0))
          row("Business stress", percent(Double(model.city?.districtStress[index] ?? 0) / 100))
          row("Economic specialization", district.dominantIndustry.rawValue.capitalized)
        }
        Section("Businesses in this district") {
          ForEach(model.entities?.businesses.filter { $0.districtID == id } ?? []) { business in
            NavigationLink(business.name) {
              EntityInspector(model: model, id: business.id, locate: locate)
            }
          }
        }
        locateButton(id)
      } else if id == "treasury", let treasury = model.update?.treasury {
        Section("Treasury") {
          row("Funds", money(treasury.funds))
          row("Income tax collected", money(treasury.taxCollected))
          row("Benefits paid", money(treasury.benefitsPaid))
        }
        locateButton(id)
      } else if id == "central-bank", let bank = model.update?.centralBank {
        Section("Central bank") {
          row("Policy rate", percent(Double(bank.annualRateBasisPoints) / 100))
          row("Emergency claims outstanding", money(bank.emergencyFunding))
        }
        locateButton(id)
      } else {
        EmptyFinancialState(
          title: "Entity unavailable",
          detail: "This identifier is not present in the current economy.")
      }
      if let events = evidence?.events, !events.isEmpty {
        Section("Recorded changes") {
          ForEach(Array(events.enumerated()), id: \.offset) { _, event in
            Text("Day \(event.day): \(event.message)").font(.subheadline)
          }
        }
      }
      if let transactions = evidence?.transactions, !transactions.isEmpty {
        Section("Actual account activity") {
          ForEach(transactions) { transaction in
            NavigationLink {
              TransactionInspector(transaction: transaction, model: model)
            } label: {
              TransactionRow(transaction: transaction)
            }
          }
        }
      }
      if let queryError { Text(queryError).font(.caption).foregroundStyle(.orange) }
    }.navigationTitle(entityName).navigationBarTitleDisplayMode(.inline).toolbar {
      ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
    }
    .task(
      id:
        "\(model.update?.seed ?? 0)-\(model.world.rawValue)-\(model.update?.metrics.day ?? 0)-\(id)"
    ) {
      do {
        let result = try await model.evidence(id: id)
        if !Task.isCancelled {
          evidence = result
          queryError = nil
        }
      } catch { if !Task.isCancelled { queryError = String(describing: error) } }
    }
  }
  private func relation(_ title: String, _ related: String) -> some View {
    NavigationLink {
      EntityInspector(model: model, id: related, locate: locate)
    } label: {
      LabeledContent(title, value: name(related))
    }
  }
  private func name(_ related: String) -> String {
    model.entities?.businesses.first { $0.id == related }?.name ?? model.update?.banks.first {
      $0.id == related
    }?.name ?? model.update?.districts.first { $0.id == related }?.name ?? related
  }
  private func row(_ title: String, _ value: String) -> some View {
    LabeledContent(title) {
      Text(value).multilineTextAlignment(.trailing).foregroundStyle(.primary).textSelection(
        .enabled)
    }
  }
  private func locateButton(_ target: String) -> some View {
    Button {
      if let locate {
        locate(target)
      } else {
        model.preferences.focus(target)
        dismiss()
      }
    } label: {
      Label("Locate in city", systemImage: "viewfinder").frame(minHeight: 44)
    }
  }
}
