import SwiftUI

#if canImport(UIKit)
  import UIKit
#else
  import AppKit
#endif

@main
struct EconopolisApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @State private var coordinator = AppCoordinator()
  var body: some Scene {
    WindowGroup {
      MobileRootView(model: coordinator.simulation, storageError: coordinator.storageError)
        .preferredColorScheme(coordinator.simulation.preferences.colorScheme)
        .tint(.blue)
        .task { coordinator.start() }
        .onChange(of: scenePhase) { _, phase in
          switch phase {
          case .active: coordinator.simulation.foreground()
          case .inactive: coordinator.simulation.inactive()
          case .background: coordinator.simulation.background()
          @unknown default: coordinator.simulation.background()
          }
        }
        #if canImport(UIKit)
          .onReceive(
            NotificationCenter.default.publisher(
              for: UIApplication.didReceiveMemoryWarningNotification)
          ) { _ in coordinator.simulation.memoryWarning() }
        #else
          .frame(minWidth: 980, minHeight: 720)
        #endif
    }
    #if os(macOS)
      .defaultSize(width: 1180, height: 840)
    #endif
  }
}
