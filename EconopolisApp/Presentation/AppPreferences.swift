import Observation
import SwiftUI

#if canImport(UIKit)
  import UIKit
#else
  import AppKit
#endif

@MainActor @Observable final class AppPreferences {
  var quality: GraphicsQuality {
    didSet { UserDefaults.standard.set(quality.rawValue, forKey: "graphicsQuality") }
  }
  var flows: Bool { didSet { UserDefaults.standard.set(flows, forKey: "showFlows") } }
  var appearance: String { didSet { UserDefaults.standard.set(appearance, forKey: "appearance") } }
  var haptics = true
  @ObservationIgnored var renderEntityCount = 0
  @ObservationIgnored var lastRenderUpdateMS = 0.0
  @ObservationIgnored var cameraPose = CityCameraPose()
  var heatmap: HeatmapMode = .off
  var cameraReset: Int = 0
  var focusID: String?
  var focusRevision = 0
  init() {
    quality =
      GraphicsQuality(rawValue: UserDefaults.standard.string(forKey: "graphicsQuality") ?? "")
      ?? .balanced
    flows = UserDefaults.standard.object(forKey: "showFlows") as? Bool ?? true
    appearance = UserDefaults.standard.string(forKey: "appearance") ?? "System"
  }
  var colorScheme: ColorScheme? {
    appearance == "Dark" ? .dark : (appearance == "Light" ? .light : nil)
  }
  func feedback() {
    #if canImport(UIKit)
      if haptics { UISelectionFeedbackGenerator().selectionChanged() }
    #endif
  }

  func resetCamera() {
    cameraReset += 1
    focusID = nil
    feedback()
  }
  func focus(_ id: String) {
    focusID = id
    focusRevision += 1
    feedback()
  }
}
