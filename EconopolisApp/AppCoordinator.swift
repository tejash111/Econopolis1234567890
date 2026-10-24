import Foundation
import Observation

@MainActor @Observable
final class AppCoordinator {
  let simulation = SimulationViewModel()
  private var started = false
  private(set) var storageError: String?
  func start() {
    guard !started else { return }
    started = true
    do {
      simulation.initialize(
        store: try SessionStore(
          inMemory: ProcessInfo.processInfo.arguments.contains("-econopolis-ui-testing")))
    } catch {
      storageError = "Local storage unavailable: \(error). Session is in memory."
      simulation.initialize()
    }
  }
}
