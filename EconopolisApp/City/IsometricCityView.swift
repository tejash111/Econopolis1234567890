import SwiftUI

/// A single Canvas, with no per-citizen SwiftUI views. Available on low-memory devices and by user choice.
struct IsometricCityView: View {
  let snapshot: CityPresentationSnapshot
  @Bindable var preferences: AppPreferences
  private var lots: [CityLot] { snapshot.lots }
  let onSelect: (String) -> Void
  @State private var scale = 1.0
  @State private var offset = CGSize.zero
  @GestureState private var magnification = 1.0
  @GestureState private var translation = CGSize.zero
  private func point(_ lot: CityLot, size: CGSize) -> CGPoint {
    let s = scale * magnification * min(size.width / 43, size.height / 32)
    return CGPoint(
      x: size.width / 2 + Double(lot.x - lot.z) * s + offset.width + translation.width,
      y: size.height / 2 + Double(lot.x + lot.z) * s * 0.48 - Double(lot.height) * s + offset.height
        + translation.height)
  }
  var body: some View {
    GeometryReader { geometry in
      Canvas { context, size in
        for lot in lots.sorted(by: { $0.x + $0.z < $1.x + $1.z }) {
          let p = point(lot, size: size)
          let unit = scale * magnification * min(size.width / 43, size.height / 32)
          let rect = CGRect(
            x: p.x - unit * 0.45, y: p.y, width: unit * 0.9,
            height: max(5, Double(lot.height) * unit))
          let colors: [Color] = [.mint, .cyan, .blue, .indigo, .purple, .teal]
          context.fill(
            Path(roundedRect: rect, cornerRadius: 3),
            with: .color(
              lot.failed
                ? .gray
                : (preferences.heatmap == .off
                  ? (lot.isBank ? .white : colors[lot.district % 6]) : heatColor(lot.district))))
          let roof = CGRect(x: rect.minX, y: rect.minY - 3, width: rect.width, height: 6)
          context.fill(Path(ellipseIn: roof), with: .color(.white.opacity(0.4)))
        }
      }
      .onChange(of: preferences.cameraReset) { _, _ in
        scale = 1
        offset = .zero
      }
      .onChange(of: preferences.focusRevision) { _, _ in
        guard let id = preferences.focusID else { return }
        let lot =
          lots.first { $0.id == id }
          ?? lots.first {
            snapshot.districts.indices.contains($0.district)
              && snapshot.districts[$0.district].id == id
          }
        guard let lot else { return }
        scale = 1.8
        let unit = scale * min(geometry.size.width / 43, geometry.size.height / 32)
        offset = CGSize(
          width: -Double(lot.x - lot.z) * unit, height: -Double(lot.x + lot.z) * unit * 0.48)
      }
      .contentShape(Rectangle())

      .gesture(
        MagnifyGesture().updating($magnification) { value, state, _ in state = value.magnification }
          .onEnded { scale = max(0.5, min(4, scale * $0.magnification)) }
      )
      .simultaneousGesture(
        DragGesture().updating($translation) { value, state, _ in state = value.translation }
          .onEnded {
            offset.width += $0.translation.width
            offset.height += $0.translation.height
          }
      )
      .simultaneousGesture(
        SpatialTapGesture().onEnded { tap in
          if let lot = lots.min(by: {
            distance(point($0, size: geometry.size), tap.location)
              < distance(point($1, size: geometry.size), tap.location)
          }), distance(point(lot, size: geometry.size), tap.location) < 40 {
            onSelect(lot.id)
          }
        }
      )
      .accessibilityLabel(
        "Isometric city. Use the institutions list below to select a business or bank.")
    }
  }
  private func heatColor(_ district: Int) -> Color {
    let score = snapshot.heat(preferences.heatmap, district: district)
    return score < 3_500 ? .green : (score < 7_000 ? .orange : .red)
  }
  private func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }
}
