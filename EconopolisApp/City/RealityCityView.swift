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
      .disableMotionBlur, .disableDepthOfField, .disableCameraGrain, .disableAREnvironmentLighting,
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
  @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    private weak var view: ARView?
    let preferences: AppPreferences
    var onSelect: (String) -> Void
    private let root = AnchorEntity(world: .zero), terrain = Entity(), buildings = Entity(),
      markers = Entity(), flows = Entity()
    private let resources = CityResources()
    private let camera = PerspectiveCamera()
    private var pose = CityCameraPose()
    private var models: [String: Entity] = [:], halos: [String: ModelEntity] = [:],
      tiles: [ModelEntity] = []
    private var known: [String: CityLot] = [:]
    private var lastIdentity = "", lastDay = -1, lastTransaction = 0,
      lastHeatmap: HeatmapMode = .off
    private var resetRevision = -1, focusRevision = -1, quality: GraphicsQuality?
    private var cleanupTask: Task<Void, Never>?
    private var current: CityPresentationSnapshot?
    private var lastBranch: String?
    private var darkAppearance = false
    private var appearanceInitialized = false
    init(preferences: AppPreferences, onSelect: @escaping (String) -> Void) {
      self.preferences = preferences
      self.onSelect = onSelect
      pose = preferences.cameraPose
      resetRevision = preferences.cameraReset
    }
    func install(_ view: ARView) {
      self.view = view
      view.scene.addAnchor(root)
      root.addChild(terrain)
      root.addChild(buildings)
      root.addChild(markers)
      root.addChild(flows)
      root.addChild(camera)
      camera.camera.fieldOfViewInDegrees = 48
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
    private func districtColor(_ index: Int) -> UIColor {
      if darkAppearance { return resources.colors[index % 6].withBrightness(0.38) }
      let base = resources.colors[index % 6]
      var red: CGFloat = 0
      var green: CGFloat = 0
      var blue: CGFloat = 0
      var alpha: CGFloat = 0
      base.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
      return UIColor(
        red: 0.82 + red * 0.14, green: 0.82 + green * 0.14, blue: 0.82 + blue * 0.14, alpha: 1)
    }
    private func environment(
      _ snapshot: CityPresentationSnapshot
    ) {
      terrain.children.removeAll()
      tiles.removeAll()
      terrain.addChild(
        resources.block(
          [27, 0.28, 18], [0, -0.25, 0],
          color: darkAppearance ? UIColor(white: 0.13, alpha: 1) : UIColor(white: 0.83, alpha: 1)))
      for (i, district) in snapshot.districts.enumerated() {
        let center = CityLayout.center(i)
        let tile = resources.block(
          [7.7, 0.08, 7.5], center + [0, -0.04, 0],
          color: districtColor(i), name: district.id)
        tile.collision = CollisionComponent(shapes: [.generateBox(size: [1, 1, 1])])
        tiles.append(tile)
        terrain.addChild(tile)
        for p in 0..<3 {
          let origin = center + SIMD3<Float>(2.9, 0, Float(p) * 1.2 - 1)
          let trunk = resources.block([0.07, 0.35, 0.07], origin + [0, 0.17, 0], color: .brown)
          terrain.addChild(trunk)
          let tree = ModelEntity(
            mesh: resources.sphere,
            materials: [resources.material(UIColor(red: 0.15, green: 0.4, blue: 0.28, alpha: 1))])
          tree.scale = [0.3, 0.38, 0.3]
          tree.position = origin + [0, 0.56, 0]
          terrain.addChild(tree)
        }
      }
      for x: Float in [-4.2, 4.2] {
        terrain.addChild(resources.block([0.48, 0.025, 17.7], [x, 0.012, 0], color: .darkGray))
        for z in stride(from: Float(-8), through: Float(8), by: 1.2) {
          terrain.addChild(
            resources.block(
              [0.035, 0.028, 0.4], [x, 0.03, z], color: UIColor(white: 0.65, alpha: 1)))
        }
      }
      terrain.addChild(resources.block([26.5, 0.025, 0.5], [0, 0.015, 0], color: .darkGray))
      // Harbor water and piers are procedural scenery, not invented economic entities.
      terrain.addChild(
        resources.block(
          [7.3, 0.035, 1.0], CityLayout.center(2) + [0, 0.005, 3.2],
          color: UIColor(red: 0.07, green: 0.28, blue: 0.4, alpha: 1)))
    }
    func update(
      _ snapshot: CityPresentationSnapshot, selection: String?, reduceMotion: Bool, dark: Bool
    ) {
      let start = ContinuousClock.now
      current = snapshot
      if !appearanceInitialized || darkAppearance != dark {
        darkAppearance = dark
        appearanceInitialized = true
        if lastIdentity == snapshot.identity { environment(snapshot) }
        lastDay = -1
      }
      if lastBranch != snapshot.branch.rawValue {
        flows.children.removeAll()
        cleanupTask?.cancel()
        lastTransaction = snapshot.flows.map(\.id).max() ?? 0
        // Refresh heatmaps and density when equal-day worlds have different outcomes.
        lastDay = -1
        lastBranch = snapshot.branch.rawValue
      }
      if lastIdentity != snapshot.identity {
        cleanupTask?.cancel()
        buildings.children.removeAll()
        markers.children.removeAll()
        flows.children.removeAll()
        models.removeAll()
        halos.removeAll()
        known.removeAll()
        environment(snapshot)
        lastIdentity = snapshot.identity
        lastTransaction = snapshot.flows.map(\.id).max() ?? 0
        lastDay = -1
      }
      let valid = Set(snapshot.lots.map(\.id))
      for id in Array(models.keys) where !valid.contains(id) {
        models.removeValue(forKey: id)?.removeFromParent()
        halos.removeValue(forKey: id)?.removeFromParent()
        known.removeValue(forKey: id)
      }
      for lot in snapshot.lots {
        if models[lot.id] == nil {
          let model = resources.building(lot)
          models[lot.id] = model
          buildings.addChild(model)
          let halo = resources.block(
            [1.04, 0.035, 1.04], [lot.x, 0.05, lot.z], color: .systemCyan)
          halos[lot.id] = halo
          buildings.addChild(halo)
        }
        if known[lot.id] != lot {
          models[lot.id]?.position = [lot.x, 0, lot.z]
          models[lot.id]?.scale = [1, lot.height, 1]
          known[lot.id] = lot
        }
        let selected = lot.selectionID == selection
        halos[lot.id]?.isEnabled = selected || lot.stress > 6_000
        halos[lot.id]?.model?.materials = [
          resources.material(
            selected ? .systemCyan : (lot.stress >= 8_000 ? .systemRed : .systemOrange))
        ]
      }
      if lastDay != snapshot.day || lastHeatmap != preferences.heatmap {
        for (i, tile) in tiles.enumerated() {
          let score = snapshot.heat(preferences.heatmap, district: i)
          let color: UIColor =
            preferences.heatmap == .off
            ? districtColor(i)
            : (score < 3_500 ? .systemGreen : (score < 7_000 ? .systemOrange : .systemRed))
          tile.model?.materials = [
            resources.material(
              color.withBrightness(preferences.heatmap == .off ? 1 : (darkAppearance ? 0.6 : 1)))
          ]
        }
        lastHeatmap = preferences.heatmap
      }
      if quality != preferences.quality || lastDay != snapshot.day {
        markers.children.removeAll()
        for marker in snapshot.markers.prefix(preferences.quality.markerLimit) {
          let dot = ModelEntity(
            mesh: resources.sphere,
            materials: [resources.material(marker.work ? .systemOrange : .systemCyan)])
          let radius: Float = marker.work ? 0.1 : 0.055
          dot.scale = [radius, radius, radius]
          dot.position = [marker.x, 0.16, marker.z]
          markers.addChild(dot)
        }
        quality = preferences.quality
      }
      if preferences.flows && !reduceMotion && lastDay >= 0 && snapshot.day > lastDay {
        animate(snapshot.flows.filter { $0.id > lastTransaction })
      }
      if !preferences.flows || reduceMotion {
        flows.children.removeAll()
        cleanupTask?.cancel()
      }
      lastTransaction = max(lastTransaction, snapshot.flows.map(\.id).max() ?? 0)
      lastDay = snapshot.day
      if resetRevision != preferences.cameraReset {
        pose = CityCameraPose()
        resetRevision = preferences.cameraReset
        positionCamera()
      }
      if focusRevision != preferences.focusRevision {
        focusRevision = preferences.focusRevision
        if let id = preferences.focusID { focus(id) }
      }
      preferences.renderEntityCount = models.count + markers.children.count
      let elapsed = (ContinuousClock.now - start).components
      preferences.lastRenderUpdateMS =
        Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
    }
    private func animate(_ transfers: [CityFlow]) {
      cleanupTask?.cancel()
      flows.children.removeAll()
      for flow in transfers.prefix(preferences.quality.flowLimit) {
        let particle = ModelEntity(
          mesh: resources.sphere, materials: [resources.material(.systemCyan)])
        particle.scale = [0.085, 0.085, 0.085]
        particle.position = flow.from
        flows.addChild(particle)
        var target = particle.transform
        target.translation = flow.to
        particle.move(to: target, relativeTo: flows, duration: 1.2, timingFunction: .easeInOut)
      }
      cleanupTask = Task { [weak self] in
        do {
          try await Task.sleep(for: .seconds(1.4))
          self?.flows.children.removeAll()
        } catch {}
      }
    }
    private func positionCamera() {
      camera.look(at: pose.target, from: pose.position, relativeTo: nil)
      preferences.cameraPose = pose
    }
    private func focus(_ id: String) {
      if let lot = current?.lots.first(where: { $0.selectionID == id || $0.id == id }) {
        pose.target = [lot.x, 0.5, lot.z]
        pose.distance = 15
      } else if let i = current?.districts.firstIndex(where: { $0.id == id }) {
        pose.target = CityLayout.center(i)
        pose.distance = 22
      }
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
    @objc private func tap(_ gesture: UITapGestureRecognizer) { select(gesture.location(in: view)) }
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
    func cleanup() {
      cleanupTask?.cancel()
      view = nil
      current = nil
    }
  }
}
