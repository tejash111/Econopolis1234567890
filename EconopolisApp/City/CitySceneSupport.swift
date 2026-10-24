import Foundation
import RealityKit
import simd

#if canImport(UIKit)
  import UIKit
#else
  import AppKit
  typealias UIColor = NSColor
#endif

struct CityCameraPose: Equatable, Sendable {
  var yaw: Float = 0.62
  var pitch: Float = 0.72
  var distance: Float = 52
  var target: SIMD3<Float> = .zero
  mutating func orbit(x: Float, y: Float) {
    guard x.isFinite, y.isFinite else { return }
    yaw -= x * 0.006
    pitch = max(0.28, min(1.3, pitch + y * 0.004))
  }
  mutating func pan(x: Float, z: Float) {
    guard x.isFinite, z.isFinite else { return }
    target.x = max(-16, min(16, target.x - x * 0.025))
    target.z = max(-12, min(12, target.z - z * 0.025))
  }
  mutating func zoom(_ scale: Float) {
    guard scale > 0, scale.isFinite else { return }
    distance = max(10, min(70, distance / scale))
  }
  var position: SIMD3<Float> {
    target + SIMD3<Float>(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
  }
}
@MainActor final class CityResources {
  let box = MeshResource.generateBox(size: 1, cornerRadius: 0.025)
  let sphere = MeshResource.generateSphere(radius: 1)
  let colors: [UIColor] = [
    UIColor(red: 0.27, green: 0.42, blue: 0.55, alpha: 1), .systemTeal,
    UIColor(red: 0.43, green: 0.53, blue: 0.56, alpha: 1),
    UIColor(red: 0.5, green: 0.43, blue: 0.35, alpha: 1),
    UIColor(red: 0.53, green: 0.57, blue: 0.62, alpha: 1),
    UIColor(red: 0.46, green: 0.56, blue: 0.53, alpha: 1),
  ]
  func material(_ color: UIColor) -> UnlitMaterial { UnlitMaterial(color: color) }
  func block(_ size: SIMD3<Float>, _ position: SIMD3<Float>, color: UIColor, name: String = "")
    -> ModelEntity
  {
    let entity = ModelEntity(mesh: box, materials: [material(color)])
    entity.scale = size
    entity.position = position
    entity.name = name
    return entity
  }
  func building(_ lot: CityLot) -> Entity {
    let root = Entity()
    root.name = lot.selectionID
    let base = colors[lot.district % colors.count]
    let width: Float = lot.kind == .warehouse || lot.kind == .factory ? 0.96 : 0.72
    let body = block([width, 1, width], [0, 0.5, 0], color: base, name: lot.selectionID)
    body.components.set(InputTargetComponent())
    body.collision = CollisionComponent(shapes: [.generateBox(size: [1, 1, 1])])
    root.addChild(body)
    // Reused, geometric facades give a miniature model readable depth without costly PBR/shadows.
    root.addChild(
      block([width, 0.96, 0.018], [0, 0.5, width / 2], color: base.withBrightness(0.67)))
    root.addChild(
      block([0.018, 0.96, width], [width / 2, 0.5, 0], color: base.withBrightness(0.83)))
    root.addChild(
      block([width + 0.04, 0.055, width + 0.04], [0, 1.02, 0], color: base.withBrightness(1.35)))
    let windows: UIColor =
      lot.isBank ? .systemCyan : UIColor(red: 0.73, green: 0.79, blue: 0.72, alpha: 1)
    for row in 0..<(lot.kind == .shop || lot.kind == .warehouse ? 1 : 4) {
      root.addChild(
        block(
          [width * 0.74, 0.045, 0.025], [0, 0.22 + Float(row) * 0.18, width / 2 + 0.02],
          color: windows))
    }
    if lot.kind == .bank {
      root.addChild(block([0.15, 0.32, 0.15], [0, 1.18, 0], color: .systemCyan))
      root.addChild(
        block(
          [width + 0.2, 0.08, width + 0.2], [0, 0.08, 0], color: UIColor(white: 0.75, alpha: 1)))
    }
    if lot.kind == .factory {
      root.addChild(block([0.15, 0.55, 0.15], [0.3, 1.22, -0.2], color: .darkGray))
    }
    if lot.kind == .university || lot.kind == .civic {
      root.addChild(
        block(
          [1.0, 0.1, 0.9], [0, 1.07, 0],
          color: UIColor(red: 0.69, green: 0.66, blue: 0.53, alpha: 1)))
    }
    return root
  }
}
extension UIColor {
  func withBrightness(_ factor: CGFloat) -> UIColor {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    #if os(macOS)
      (usingColorSpace(.deviceRGB) ?? self).getRed(&r, green: &g, blue: &b, alpha: &a)
    #else
      getRed(&r, green: &g, blue: &b, alpha: &a)
    #endif

    return UIColor(
      red: min(1, r * factor), green: min(1, g * factor), blue: min(1, b * factor), alpha: a)
  }
}
