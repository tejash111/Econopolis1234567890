import SwiftUI

extension View {
  @ViewBuilder func economicGroupedList() -> some View {
    #if os(macOS)
      self.listStyle(.inset)
    #else
      self.listStyle(.insetGrouped)
    #endif
  }
}
#if os(macOS)
  /// Only mobile-specific styling is adapted; financial views and model ownership are shared.
  enum MacNavigationDisplayMode { case inline, large, automatic }
  enum MacTextCapitalization { case never }
  enum MacKeyboardType { case decimalPad }
  extension View {
    func navigationBarTitleDisplayMode(_ mode: MacNavigationDisplayMode) -> some View { self }
    func textInputAutocapitalization(_ value: MacTextCapitalization) -> some View { self }
    func keyboardType(_ value: MacKeyboardType) -> some View { self }
  }
  extension ToolbarItemPlacement {
    static var topBarTrailing: Self { .primaryAction }
    static var topBarLeading: Self { .navigation }
  }
  extension SearchFieldPlacement {
    static func navigationBarDrawer(displayMode: MacSearchDisplayMode) -> Self { .automatic }
  }
  enum MacSearchDisplayMode { case always }
#endif
