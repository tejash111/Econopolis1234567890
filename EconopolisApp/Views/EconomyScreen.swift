import Charts
import EconopolisCore
import SwiftUI

struct EconomyScreen: View {
  @Bindable var model: SimulationViewModel
  let select: (String) -> Void
  @State private var metric: EconomyChartMetric = .spending
  @State private var range = 30
  @State private var district = ""
  @State private var points: [ChartSample] = []
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        WorldPicker(model: model)
        if let update = model.update {
          HStack(alignment: .firstTextBaseline) {
            Text("The pulse of your city").font(.title2.bold())
            Spacer()
            Text("Day \(update.metrics.day)").font(.caption.monospacedDigit()).foregroundStyle(
              .secondary)
          }
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            MetricCard(
              title: "Spending today", value: compactMoney(update.metrics.consumerSpending))
            MetricCard(title: "Unemployment", value: percent(update.metrics.unemploymentPercentage))
            MetricCard(
              title: "Household debt", value: compactMoney(update.metrics.aggregateHouseholdDebt))
            MetricCard(
              title: "Transfers today", value: compactMoney(update.metrics.transactionVolume))
            MetricCard(
              title: "Employment / labor force",
              value: "\(update.metrics.employed) / \(update.metrics.laborForce)")
            MetricCard(
              title: "Active / failed firms",
              value: "\(update.metrics.activeBusinesses) / \(update.metrics.failedBusinesses)")
            MetricCard(title: "Confidence", value: percent(update.metrics.averageConfidence))
            MetricCard(
              title: "Bank funding stress", value: percent(update.metrics.bankLiquidityStress))
            MetricCard(title: "Household stress · now", value: percent(householdStress))
            MetricCard(title: "System stress", value: percent(update.metrics.financialStress))
          }
          VStack(alignment: .leading, spacing: 14) {
            Picker("Historical metric", selection: $metric) {
              ForEach(EconomyChartMetric.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu).accessibilityIdentifier("chartMetric")
            Picker("History range", selection: $range) {
              Text("14D").tag(14)
              Text("30D").tag(30)
              Text("90D").tag(90)
              Text("All").tag(0)
            }.pickerStyle(.segmented)
            if metric.supportsDistrict {
              Picker("District", selection: $district) {
                Text("Whole city").tag("")
                ForEach(update.districts) { Text($0.name).tag($0.id) }
              }
            }
            if points.count < 2 {
              EmptyFinancialState(
                title: "History is just beginning",
                detail: "Advance at least one day to compare recorded values.")
            } else {
              Chart(points) { point in
                AreaMark(
                  x: .value("Simulation day", point.day), y: .value(metric.rawValue, point.value)
                ).foregroundStyle(.cyan.opacity(0.08))
                LineMark(
                  x: .value("Simulation day", point.day), y: .value(metric.rawValue, point.value)
                ).foregroundStyle(.cyan).lineStyle(StrokeStyle(lineWidth: 2))
              }.frame(height: 190).chartXAxisLabel("Simulation day").chartYAxisLabel(
                metric.monetary ? "Fictional USD" : metric.rawValue
              ).accessibilityLabel("\(metric.rawValue), \(points.count) actual recorded days")
            }
          }.padding(14).background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 20))
          TimelinePanel(model: model)
          if model.demoStage >= 2 { ComparisonPanel(model: model) }
          Text("District spending today").font(.title3.bold())
          Chart(update.metrics.districts) { activity in
            BarMark(
              x: .value("Fictional dollars", Double(activity.consumerSpending) / 100),
              y: .value(
                "District",
                update.districts.first { $0.id == activity.id }?.name.components(separatedBy: " ")
                  .first ?? activity.id)
            ).foregroundStyle(.cyan)
          }.frame(height: 180).accessibilityLabel(
            "Actual current-day consumer spending by seller district")
          ForEach(update.districts) { district in
            Button {
              select(district.id)
            } label: {
              HStack {
                Text(district.name)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
              }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
          }
          NavigationLink {
            ActivityFeed(model: model)
          } label: {
            Label("Explore the transaction journal", systemImage: "list.bullet.rectangle")
          }.frame(minHeight: 44).contentShape(Rectangle())
          Text(
            "Recorded economic activity and monetary proxies, not GDP or market forecasts. Data is never interpolated to invent historical values."
          ).font(.caption).foregroundStyle(.secondary)
        }
      }.padding(16)
    }.background(Color.cityNight).navigationTitle("Economy").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            ForEach(DirectoryKind.allCases) { kind in
              NavigationLink(kind.rawValue) { directory(kind) }
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }.accessibilityLabel("Economy directories and settings")
        }
      }
      .task(
        id:
          "\(model.world)-\(model.update?.seed ?? 0)-\(model.update?.metrics.day ?? 0)-\(metric)-\(range)-\(district)"
      ) {
        points = ChartProjection.samples(
          history: model.update?.history ?? [], metric: metric, range: range, district: district)
      }
  }
  private var householdStress: Double {
    let residents = model.entities?.citizens ?? []
    return residents.isEmpty
      ? 0 : Double(residents.reduce(0) { $0 + $1.stress }) / Double(residents.count * 100)
  }
  @ViewBuilder private func directory(_ kind: DirectoryKind) -> some View {
    switch kind {
    case .information: EconomyInformation(model: model)
    case .settings: SettingsScreen(model: model)
    default: InstitutionDirectory(model: model, category: kind)
    }
  }
}
