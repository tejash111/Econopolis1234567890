# Native iOS appearance refresh

The user requested colors and typography resembling Apple's built-in iPhone apps. No matching installed Swift/iOS design skill was found, so the implementation used Apple's official documentation directly.

## Research and decisions

- [Apple HIG: Color](https://developer.apple.com/design/human-interface-guidelines/color): semantic system backgrounds, grouped content hierarchy, adaptive text and blue interactive accents.
- [Apple: System fonts](https://developer.apple.com/documentation/technologyoverviews/fonts) and [Typography](https://developer.apple.com/design/human-interface-guidelines/typography): standard dynamic SwiftUI text styles; financial numbers retain tabular digits.
- [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials): neutral native glass on floating controls/navigation, standard content surfaces for readable financial text.

The app now follows System appearance by default, retaining explicit Light/Dark settings. The prior custom navy backdrop and cyan/violet UI accents were replaced with `systemGroupedBackground`, `secondarySystemGroupedBackground`, primary/secondary labels and system blue. Financial status colors remain semantic green/orange/red.

Crisis Lab and AI Economist now use native inset grouped sections. Economy has native large-title navigation, clearer metric type and blue charts. City retains the interactive 3D economy with a compact system-font identity, adaptive ground/background and blue controls. Its camera and economic state are preserved when appearance changes. Accessibility-size metric layouts use one column. New economist answers scroll into view.

## Actual verification

- Debug iPhone Simulator build: succeeded (`.build/native-ui-build.log`).
- Light/Dark screen verification: passed, both appearances across all five tabs (`.build/NativeAppearanceVisuals.xcresult`). Actual captures are under `docs/Screenshots/NativeUI/`.
- Existing presentation and playback suites: seven tests passed during the first integrated targeted run.
- Full bank-run/rewind/rescue/citizen/economist UI case: passed (`.build/NativeDemoFocused.xcresult`).
- Final complete UI regression and updated release archive results are recorded in TEST_REPORT.md.

Early UI runs exposed Simulator accessibility hit-point lookup problems and test waits that scrolled a lazy list before a new demo stage was ready. Tests now tap the real visible control frame when needed and wait for asynchronous demo labels. Assertions still verify actual screens and computed day changes; no engine shortcuts, fake controls or mocked simulation outcomes were introduced. The warmup test explicitly checks that the real City reaches day seven.

Financial source under `Packages/EconopolisCore` is unchanged by this refresh. Physical-device graphics/energy/accessibility profiling remains unverified, as described in the main test report.

Final appearance-only regression: `.build/NativeUIFinal.xcresult`, **5 passed, 0 failed**. Subsequent optional-market integration: `.build/StocksNativeFinal.xcresult`, **22 passed, 0 failed, 0 skipped**, including six UI tests and sixteen hosted tests. One internal QoS warning remains for profiling in the combined run. Current gallery captures were refreshed from the passing integration bundle, including the new Economy entry point. The signed-Simulator Keychain requirement is documented in LIVE_STOCKS.md.
