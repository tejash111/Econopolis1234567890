#if os(macOS)
  import AppKit
  import SwiftUI

  /// Keeps each existing SwiftUI destination alive while showing only the selected one.
  /// The financial screens, scene controller and model remain shared with iPhone.
  struct MacTabContent<Content: View>: NSViewRepresentable {
    let selection: AppTab
    @ViewBuilder let content: (AppTab) -> Content
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ container: NSView, context: Context) {
      let host: NSHostingView<Content>
      if let existing = context.coordinator.hosts[selection] {
        host = existing
        host.rootView = content(selection)
      } else {
        host = NSHostingView(rootView: content(selection))
        context.coordinator.hosts[selection] = host
      }
      guard host.superview !== container else { return }
      container.subviews.forEach { $0.removeFromSuperview() }
      host.frame = container.bounds
      host.autoresizingMask = [.width, .height]
      container.addSubview(host)
    }
    @MainActor final class Coordinator {
      var hosts: [AppTab: NSHostingView<Content>] = [:]
    }
  }
  struct MacBottomTabs: View {
    @Binding var selection: AppTab
    private let items: [(AppTab, String, String, KeyEquivalent)] = [
      (.city, "City", "building.2.crop.circle", "1"),
      (.economy, "Economy", "chart.xyaxis.line", "2"),
      (.crisis, "Crisis Lab", "waveform.path.ecg", "3"),
      (.citizens, "Citizens", "person.2", "4"),
      (.economist, "AI Economist", "sparkles", "5"),
    ]
    var body: some View {
      HStack(spacing: 6) {
        ForEach(items.indices, id: \.self) { index in
          let item = items[index]
          Button {
            selection = item.0
          } label: {
            VStack(spacing: 4) {
              Image(systemName: item.2).font(.system(size: 23, weight: .regular))
              Text(item.1).font(.system(size: 12, weight: .medium))
            }.frame(maxWidth: .infinity).frame(height: 62)
              .foregroundStyle(selection == item.0 ? Color.blue : Color.primary)
              .background(
                selection == item.0 ? Color.primary.opacity(0.07) : .clear,
                in: RoundedRectangle(cornerRadius: 28)
              )
              .contentShape(Rectangle())
          }.buttonStyle(.plain).keyboardShortcut(item.3, modifiers: .command)
            .accessibilityLabel(item.1).accessibilityAddTraits(
              selection == item.0 ? .isSelected : [])
        }
      }.padding(7).frame(maxWidth: 620).economicGlass()
        .padding(.horizontal, 18).padding(.bottom, 10)
    }
  }
#endif
