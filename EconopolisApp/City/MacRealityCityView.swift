#if os(macOS)
  import RealityKit
  import SwiftUI

  /// Native Mac surface for the exact scene controller used by the iPhone renderer.
  struct RealityCityView: View {
    let snapshot: CityPresentationSnapshot
    let preferences: AppPreferences
    let reducedMotion: Bool
    let selection: String?
    let onSelect: (String) -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var controller: CitySceneController?
    @State private var previousDrag = CGSize.zero
    @State private var previousMagnification = 1.0
    var body: some View {
      RealityView { content in
        let scene = CitySceneController(preferences: preferences, onSelect: onSelect)
        scene.update(
          snapshot, selection: selection, reduceMotion: reducedMotion, dark: scheme == .dark)
        content.camera = .virtual
        content.add(scene.root)
        controller = scene
      } update: { _ in
        controller?.onSelect = onSelect
        controller?.update(
          snapshot, selection: selection, reduceMotion: reducedMotion, dark: scheme == .dark)
      }
      .gesture(
        DragGesture(minimumDistance: 4).onChanged { value in
          guard let controller else { return }
          let x = Float(value.translation.width - previousDrag.width)
          let y = Float(value.translation.height - previousDrag.height)
          if NSEvent.modifierFlags.contains(.shift) {
            controller.pose.pan(x: x, z: y)
          } else {
            controller.pose.orbit(x: x, y: y)
          }
          previousDrag = value.translation
          controller.positionCamera()
        }.onEnded { _ in previousDrag = .zero }
      )
      .simultaneousGesture(
        MagnifyGesture().onChanged { value in
          controller?.pose.zoom(Float(value.magnification / previousMagnification))
          previousMagnification = value.magnification
          controller?.positionCamera()
        }.onEnded { _ in previousMagnification = 1 }
      )
      .simultaneousGesture(
        SpatialTapGesture().targetedToAnyEntity().onEnded { value in
          controller?.choose(value.entity)
        }
      )
      .simultaneousGesture(
        TapGesture(count: 2).onEnded {
          if let id = preferences.focusID {
            controller?.focus(id)
          } else {
            preferences.resetCamera()
          }
        }
      )
      .onDisappear {
        controller?.cleanup()
      }
      .accessibilityLabel(
        "Financial city. Drag to orbit, Shift-drag to pan, pinch to zoom and click to inspect.")
    }
  }
#endif
