#if os(iOS)
  import RealityKit
  import SwiftUI
  import UIKit
  import simd

  struct RealityCityView: UIViewRepresentable {
    let snapshot: CityPresentationSnapshot
    let preferences: AppPreferences
    let reducedMotion: Bool
    let selection: String?
    let onSelect: (String) -> Void
    @Environment(\.colorScheme) private var scheme
    func makeCoordinator() -> Coordinator {
      Coordinator(preferences: preferences, onSelect: onSelect)
    }
    func makeUIView(context: Context) -> ARView {
      let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
      view.renderOptions = [
        .disableMotionBlur, .disableDepthOfField, .disableCameraGrain,
        .disableAREnvironmentLighting,
        .disableGroundingShadows,
      ]
      context.coordinator.install(view)
      return view
    }
    func updateUIView(_ view: ARView, context: Context) {
      view.environment.background = .color(
        UIColor.systemGroupedBackground.resolvedColor(
          with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)))
      context.coordinator.onSelect = onSelect
      context.coordinator.update(
        snapshot, selection: selection, reduceMotion: reducedMotion, dark: scheme == .dark)
    }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
      coordinator.cleanup()
      view.scene.anchors.removeAll()
    }
    @MainActor final class Coordinator: CitySceneController, UIGestureRecognizerDelegate {
      private weak var view: ARView?
      func install(_ view: ARView) {
        self.view = view
        view.scene.addAnchor(root)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        let double = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        double.numberOfTapsRequired = 2
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(hold(_:)))
        tap.require(toFail: double)
        tap.require(toFail: pan)
        tap.require(toFail: hold)
        for gesture in [pan, pinch, tap, double, hold] {
          gesture.delegate = self
          view.addGestureRecognizer(gesture)
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel =
          "Financial city. Drag to orbit, two fingers to pan, pinch to zoom, double tap to focus. Use Search city for accessible institution selection."
        positionCamera()
      }
      @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        guard let view else { return }
        let delta = gesture.translation(in: view)
        gesture.setTranslation(.zero, in: view)
        if gesture.numberOfTouches > 1 {
          pose.pan(x: Float(delta.x), z: Float(delta.y))
        } else {
          pose.orbit(x: Float(delta.x), y: Float(delta.y))
        }
        positionCamera()
      }
      @objc private func pinch(_ gesture: UIPinchGestureRecognizer) {
        pose.zoom(Float(gesture.scale))
        gesture.scale = 1
        positionCamera()
      }
      private func select(_ point: CGPoint) {
        guard var entity = view?.entity(at: point) else { return }
        while entity.name.isEmpty, let parent = entity.parent { entity = parent }
        if !entity.name.isEmpty {
          preferences.feedback()
          onSelect(entity.name)
        }
      }
      @objc private func tap(_ gesture: UITapGestureRecognizer) {
        select(gesture.location(in: view))
      }
      @objc private func hold(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began { select(gesture.location(in: view)) }
      }
      @objc private func doubleTap(_ gesture: UITapGestureRecognizer) {
        if let id = preferences.focusID {
          focus(id)
        } else {
          pose = CityCameraPose()
          positionCamera()
        }
      }
      func gestureRecognizer(
        _ a: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith b: UIGestureRecognizer
      ) -> Bool {
        (a is UIPanGestureRecognizer && b is UIPinchGestureRecognizer)
          || (b is UIPanGestureRecognizer && a is UIPinchGestureRecognizer)
      }
      override func cleanup() {
        super.cleanup()
        view = nil
      }
    }
  }
#endif
