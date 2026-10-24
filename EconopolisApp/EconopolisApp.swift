import SwiftUI
import UIKit

@main
struct EconopolisApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @State private var coordinator = AppCoordinator()
  var body: some Scene {
    WindowGroup {
      MobileRootView(model: coordinator.simulation, storageError: coordinator.storageError)
        .preferredColorScheme(coordinator.simulation.preferences.colorScheme)
        .tint(.mint)
        .task { coordinator.start() }
        .onChange(of: scenePhase) { _, phase in
          switch phase {
          case .active: coordinator.simulation.foreground()
          case .inactive: coordinator.simulation.inactive()
          case .background: coordinator.simulation.background()
          @unknown default: coordinator.simulation.background()
          }
        }
        .onReceive(
          NotificationCenter.default.publisher(
            for: UIApplication.didReceiveMemoryWarningNotification)
        ) { _ in coordinator.simulation.memoryWarning() }
    }
  }
}
