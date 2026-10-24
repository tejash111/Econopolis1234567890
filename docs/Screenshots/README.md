# Actual iPhone Simulator captures

These PNGs are real renders, not mockups. Device: iPhone 17, iOS 27.0, arm64.

`BankRunCity.png`, `BankingHeatmap.png`, `CitizenInspector.png`, `OfflineEconomist.png`, and `ComputedFutures.png` are from the **passing final 47-test run**, `.build/FinalAcceptance.xcresult`. `FinalStandaloneLaunch.png` captures the final installed app after termination and normal relaunch without UI-test arguments.

`Launch.png`, `City.png` and `Isometric.png` are historical Phase 1 evidence retained for comparison. Current images above show the completed experience.

Calculated values belong to the deterministic seed-2026 demo. They are not application targets or hardcoded results. Currency grouping follows the device locale. Physical-device/landscape visual quality and performance are not inferred from these captures.

`NativeUI/` contains actual Light and Dark captures of all five destinations from the passing `NativeAppearanceVisuals.xcresult` check after the Apple-style visual refresh. Earlier images at this directory's root document the previous appearance and historical financial demo. Capture provenance and design sources are described in `../APPLE_UI_REFRESH.md`.

The `NativeUI/` gallery has now been refreshed from the later passing `StocksNativeFinal.xcresult` run (22 tests). `LiveStocks-Connect.png` and `LiveStocks-Keychain.png` show the actual missing-key state and empty secure credential form. No test fixture stock prices are presented as real quotes.
