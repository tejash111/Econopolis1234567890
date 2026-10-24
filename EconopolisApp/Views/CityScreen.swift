import EconopolisCore
import SwiftUI

struct CityScreen: View {
  @Bindable var model: SimulationViewModel
  let active: Bool
  let select: (String) -> Void
  let crisis: () -> Void
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var directory = false
  @State private var activity = false
  var body: some View {
    ZStack {
      Color.appBackground.ignoresSafeArea()
      if let city = model.city {
        if model.use2D {
          IsometricCityView(snapshot: city, preferences: model.preferences, onSelect: select)
        } else if active && scenePhase == .active {
          RealityCityView(
            snapshot: city, preferences: model.preferences, reducedMotion: reduceMotion,
            selection: model.selectedEntity, onSelect: select)
        }
        VStack(spacing: 10) {
          HStack {
            VStack(alignment: .leading, spacing: 3) {
              Text("Econopolis").font(.title2.weight(.semibold))
              Text("Your living economy").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
              Text("DAY \(city.day)").font(.headline.monospacedDigit()).accessibilityIdentifier(
                "simulationDay")
              Label(
                model.isPlaying ? "Running" : "Paused",
                systemImage: model.isPlaying ? "circle.fill" : "pause.circle"
              ).font(.caption).foregroundStyle(model.isPlaying ? .green : .secondary)
            }
          }
          WorldPicker(model: model)
          HStack {
            Text(
              "\(city.metrics.population.formatted()) citizens · \(model.entities?.businesses.count ?? 0) firms"
            ).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Label(percent(city.metrics.financialStress), systemImage: "waveform.path.ecg").font(
              .caption.monospacedDigit()
            ).foregroundStyle(city.metrics.financialStress > 50 ? .orange : .green)
              .accessibilityLabel("Financial stress \(percent(city.metrics.financialStress))")
            Button(action: crisis) { Image(systemName: "bolt.shield").frame(width: 44, height: 44) }
              .accessibilityLabel("Open Crisis Lab")
          }
          if let run = model.update?.crisis?.plans.last(where: { $0.isActive(day: city.day) }) {
            Button(action: crisis) {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(run.kind.rawValue).font(.caption.bold())
                Spacer()
                Text("Crisis Lab").font(.caption)
                Image(systemName: "chevron.right")
              }.padding(10).economicGlass()
            }.buttonStyle(.plain)
          }
          Spacer(minLength: 0)
          HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
              if model.preferences.heatmap != .off {
                Text(model.preferences.heatmap.rawValue).font(.caption.bold())
                HStack(spacing: 6) {
                  Circle().fill(.green).frame(width: 7)
                  Text(model.preferences.heatmap == .activity ? "High activity" : "Healthy")
                  Circle().fill(.orange).frame(width: 7)
                  Text("Moderate")
                  Circle().fill(.red).frame(width: 7)
                  Text(model.preferences.heatmap == .activity ? "Low" : "Stress")
                }.font(.caption2)
              } else {
                Text("Home / work density · abstract locations").font(.caption2).foregroundStyle(
                  .secondary)
              }
            }.padding(9).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            Spacer(minLength: 8)
            VStack(spacing: 10) {
              Button {
                directory = true
              } label: {
                Image(systemName: "magnifyingglass").frame(width: 44, height: 44).economicGlass(
                  interactive: true)
              }.accessibilityLabel("Search city")
              Button {
                model.preferences.resetCamera()
              } label: {
                Image(systemName: "viewfinder").frame(width: 44, height: 44).economicGlass(
                  interactive: true)
              }.accessibilityLabel("Reset camera")
              Menu {
                Picker("Financial heatmap", selection: $model.preferences.heatmap) {
                  ForEach(HeatmapMode.allCases) { Text($0.rawValue).tag($0) }
                }
              } label: {
                Image(
                  systemName: model.preferences.heatmap == .off
                    ? "square.3.layers.3d" : "square.3.layers.3d.top.filled"
                ).frame(width: 44, height: 44).economicGlass(interactive: true)
              }.accessibilityLabel("Financial heatmap")
            }.glassGroup()
          }
        }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: 9) {
        TokenizedStocksPanel(compact: true)
        Button {
          activity = true
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 3) {
              Text("Spending today").font(.caption).foregroundStyle(.secondary)
              Text(compactMoney(model.update?.metrics.consumerSpending ?? 0)).font(
                .headline.monospacedDigit())
            }
            Spacer()
            Text("Activity").font(.subheadline)
            Image(systemName: "chevron.up")
          }.padding(.horizontal, 12).frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).padding(.vertical, 8)
          .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 16))
        PlaybackBar(model: model)
      }.padding(.horizontal, 14).padding(.bottom, 5)
    }
    .sheet(isPresented: $directory) {
      NavigationStack { InstitutionDirectory(model: model) }.presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $activity) {
      NavigationStack { ActivityFeed(model: model) }.presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    .onChange(of: model.preferences.heatmap) { _, _ in model.preferences.feedback() }
  }
}
