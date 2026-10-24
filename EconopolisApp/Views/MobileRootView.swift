import EconopolisCore
import SwiftUI

enum AppTab: Hashable { case city, economy, crisis, citizens, economist }
struct EntitySelection: Identifiable { let id: String }
struct MobileRootView: View {
  @Bindable var model: SimulationViewModel
  let storageError: String?
  @State private var tab: AppTab = .city
  @State private var selected: EntitySelection?
  var body: some View {
    Group {
      if model.update != nil {
        TabView(selection: $tab) {
          CityScreen(model: model, active: tab == .city, select: select, crisis: { tab = .crisis })
            .tabItem { Label("City", systemImage: "building.2.crop.circle") }.tag(AppTab.city)
          NavigationStack { EconomyScreen(model: model, select: select) }.tabItem {
            Label("Economy", systemImage: "chart.xyaxis.line")
          }.tag(AppTab.economy)
          NavigationStack { CrisisScreen(model: model) }.tabItem {
            Label("Crisis Lab", systemImage: "waveform.path.ecg")
          }.tag(AppTab.crisis)
          NavigationStack { CitizensScreen(model: model, select: select) }.tabItem {
            Label("Citizens", systemImage: "person.2")
          }.tag(AppTab.citizens)
          NavigationStack { EconomistScreen(model: model) }.tabItem {
            Label("AI Economist", systemImage: "sparkles")
          }.tag(AppTab.economist)
        }
      } else {
        VStack(spacing: 20) {
          Image(systemName: "building.2.crop.circle").font(.system(size: 60)).foregroundStyle(.blue)
          Text("Econopolis").font(.largeTitle.bold())
          if model.error == nil {
            ProgressView("Opening your economy")
          } else {
            Text("The saved session could not be opened.")
            Button("Start a new economy") { model.reset() }.buttonStyle(.borderedProminent)
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.appBackground)
      }
    }
    .onChange(of: model.preferences.focusRevision) { _, _ in
      selected = nil
      tab = .city
    }
    .sheet(item: $selected) { selection in
      NavigationStack {
        EntityInspector(
          model: model, id: selection.id,
          locate: { id in
            selected = nil
            model.preferences.focus(id)
            tab = .city
          })
      }
      .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      if let message = model.error ?? storageError {
        Text(message).font(.caption).foregroundStyle(.orange).padding(8).frame(maxWidth: .infinity)
          .background(.background)
      }
    }
  }
  private func select(_ id: String) {
    model.selectedEntity = id
    model.preferences.focusID = id
    model.preferences.feedback()
    selected = EntitySelection(id: id)
  }
}
struct WorldPicker: View {
  @Bindable var model: SimulationViewModel
  var body: some View {
    Picker("Simulation world", selection: $model.world) {
      ForEach(WorldBranch.allCases) { Text($0.rawValue).tag($0) }
    }.pickerStyle(.segmented).accessibilityIdentifier("worldPicker")
  }
}
struct PlaybackBar: View {
  @Bindable var model: SimulationViewModel
  var body: some View {
    HStack(spacing: 8) {
      Button {
        if model.isPlaying { model.pause() } else { model.play() }
        model.preferences.feedback()
      } label: {
        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill").frame(width: 46, height: 44)
      }
      .buttonStyle(.borderedProminent).tint(.blue).accessibilityLabel(
        model.isPlaying ? "Pause simulation" : "Play simulation"
      ).accessibilityIdentifier("playPause").disabled(model.isBusy || !model.synchronized)
      Button {
        model.step()
        model.preferences.feedback()
      } label: {
        Image(systemName: "forward.end.fill").frame(width: 44, height: 44)
      }.accessibilityLabel("Advance one day").accessibilityIdentifier("stepDay").disabled(
        model.isBusy || model.isPlaying || !model.synchronized)
      Menu {
        Picker("Days per second", selection: $model.daysPerSecond) {
          Text("1 day / second").tag(1.0)
          Text("2 days / second").tag(2.0)
          Text("5 days / second").tag(5.0)
          Text("10 days / second").tag(10.0)
        }
      } label: {
        Text("\(Int(model.daysPerSecond))×").font(.headline.monospacedDigit()).frame(
          minWidth: 44, minHeight: 44)
      }.accessibilityLabel("Simulation speed")
      Spacer(minLength: 0)
      Menu {
        Button("Reset same seed", systemImage: "arrow.counterclockwise") {
          model.reset()
          model.preferences.feedback()
        }
        Button("Regenerate city", systemImage: "shuffle") { model.reset(newSeed: true) }
        Toggle("Isometric fallback", isOn: $model.use2D)
      } label: {
        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
      }.accessibilityLabel("City options").disabled(model.isBusy)
    }.padding(8).economicGlass()
  }
}
