# ECONOPOLIS combined verification report

Date: 2026-10-24. This report distinguishes actual automated results from physical-device and distribution work that has not been verified.

## Environment

Apple Silicon MacBook Air; macOS 27.0.1; Xcode 27.1; Swift 6.4; iOS SDK 27.1. Actual destination: iPhone 17, iOS 27.0, arm64, UUID `BD53D5D9-F086-4961-AE37-EAE90C04684E`. No connected physical iPhone. The iOS 27.1 runtime on this host is Duo-only; the conventional iPhone runtime is iOS 27.0.

## Commands executed

```sh
# Debug builds and integrated regression:
xcodebuild -quiet -project Econopolis.xcodeproj -scheme Econopolis -configuration Debug -derivedDataPath .build/ios -destination 'platform=iOS Simulator,id=BD53D5D9-F086-4961-AE37-EAE90C04684E' -parallel-testing-enabled NO -resultBundlePath .build/FinalAcceptance.xcresult CODE_SIGNING_ALLOWED=NO test
# Targeted complete-demo interaction run:
xcodebuild -quiet -project Econopolis.xcodeproj -scheme Econopolis -configuration Debug -derivedDataPath .build/ios -destination 'platform=iOS Simulator,id=BD53D5D9-F086-4961-AE37-EAE90C04684E' -parallel-testing-enabled NO -only-testing:EconopolisUITests/CombinedDemoUITests -resultBundlePath .build/CombinedDemoUIFixed.xcresult CODE_SIGNING_ALLOWED=NO test
# Portable core regression:
swift test --package-path Packages/EconopolisCore --scratch-path .build/core
# Additional replay/invalid-checkpoint cases:
swift test --package-path Packages/EconopolisCore --scratch-path .build/core --filter 'keyedBranchReplayAndRateExpiration|corruptCheckpointDoesNotPartiallyRestoreBranches'
# Unsigned iPhone release archive:
xcodebuild -quiet -project Econopolis.xcodeproj -scheme Econopolis -configuration Release -derivedDataPath .build/release -destination 'generic/platform=iOS' -archivePath .build/ECONOPOLIS-Final.xcarchive CODE_SIGNING_ALLOWED=NO archive
xcrun vtool -show-build .build/ECONOPOLIS-Final.xcarchive/Products/Applications/Econopolis.app/Econopolis
```

Result bundle paths cannot be reused; choose a fresh path for reruns. Debug/Release iOS compilation is actual platform validation; host package tests alone are not.

## Verified results

- Portable core final full run: **32 passed, 0 failed**, four suites, 52.688 seconds (`.build/core-verified.log`). This includes the original 21 foundation/branch tests, six-crisis evolution, public funding/reconciliation, parser validation, fictional enrollment and the 365-day standard-population shock run.
- Additional regression cases passed: keyed A/B replay with rate-shock expiration, invalid-checkpoint restore without partial branch mutation, and expired bank-run settlement recovery. The first two also passed a targeted 0.075-second run. All three are included in the final 32-test core run.
- Targeted hosted presentation/intent/player run: **8 passed, 0 failed**.
- Corrected complete-demo and city/filter/preview UI tests: **2 passed, 0 failed**, full operation 109.144 seconds. These execute actual native controls and capture screenshots.
- Unsigned generic iPhone Release archive: **exit 0**. Mach-O reports `platform IOS`, `minos 18.0`, `sdk 27.1`. Local artifact `.build/ECONOPOLIS-Final.xcarchive`. This is not signed distribution or a TestFlight upload.

Earlier integrated runs caught an outdated policy label and a real empty-spacer hit-area issue in policy rows. The label and full-row touch targets were corrected. Their failed result bundles remain in local logs; they are not counted as successful runs. Final acceptance results are recorded below.

## Measured simulation performance

Host Debug, normal default 1,000-citizen world, 90 days: **10.324668333 seconds**, **194,582 settled transactions**. This matches the original baseline transaction count.

Host Debug, 365 days with six scheduled shocks: **33.060099583 seconds**, **750,106 settled transactions**. Nonnegative constrained balances, finite stress history, reconciliation and snapshot validity passed. The bounded crisis journal retained no more than 600 records.

These are development-host wall times under a concurrent test workload, not physical-iPhone CPU/battery/FPS measurements. Frame rate, peak memory and energy use: **Not measured**. Full financial journals grow with simulated time; arbitrary multi-year memory bounds are not claimed.

The computed seed-2026 bank-run fixture recorded unmet withdrawal attempts of **142,790,866 cents in A** and **0 in B**, with an outstanding emergency claim of **140,759,567 cents in B** at the comparison horizon. These are test observations, not hardcoded outcomes or a universal rescue guarantee. Repeated unmet attempts are a flow, and the public claim is a repayable stock.

## Interaction and visual verification

Actual iPhone Simulator XCTest covered demo baseline generation, bank run, day-35 city/heatmap, day-seven rewind, liquidity replay, same-citizen inspection and grounded offline explanation. Camera drag/pinch/reset, citizen filters/no results and canceling an unexecuted policy preview were verified. Older navigation/control/lifecycle cases are included in integrated regression.

Screenshots were inspected for visible city geometry, controls, contrast and safe-area layout. Screenshot automation is available despite the normal Simulator GUI app being absent. Some landscape headless captures from the foundation were cropped/black; landscape visual quality remains unverified. No physical-device or iOS 18 runtime execution is claimed.

## Known limitations / manual checks

- Foundation Models is not integrated; the deterministic offline provider is the working assistant.
- Actual insolvency, deposit haircuts, interbank markets, collateral auctions and calibrated real-world loss forecasting are outside this custody model. Operational settlement resolution and observed contagion are explicitly labeled.
- Full journals remain unbounded; snapshots use a bounded set of full checkpoints rather than an archive-compacted ledger. Long timeline seeks replay from initial configuration.
- Canvas omits animated transaction particles; RealityKit supplies them. No custom Metal/shadow work was justified by a measured bottleneck.
- Validate on a signed physical iPhone: smaller-screen touch feel, large Dynamic Type/VoiceOver, iOS 18 material fallback, landscape layouts, memory pressure, GPU pacing and battery usage.
- Signing, provisioning, IPA export, TestFlight/App Store submission are not verified. No upload occurred.

## Final acceptance result

`.build/FinalAcceptance.xcresult`: **PASS — 47 passed, 0 failed, 0 skipped**, iPhone 17 / iOS 27.0. Xcode test operation: 258.084 seconds, including setup/automation. Hosted tests: **43 passed**, eight suites, 79.122 seconds. All **four actual UI tests passed**, including the corrected full-width policy row and complete Great Bank Run journey. Exit code 0. That result describes the combined-phase milestone; the later native UI refresh is verified separately below.

Final iOS simulator Debug benchmark: 90 days / 1,000 citizens in **7.622169708 seconds**, 194,582 settled transactions. Final iOS 365-day shock run: **31.616810917 seconds**, 750,106 settled transactions. These are simulator wall times on this development host, not real-device FPS or energy measurements.

The result bundle contains **one runtime QoS priority-inversion warning** during `MobileNavigationTests.testCityTouchAndFallback()`, with no source location. It did not fail the test; its source and device impact require Instruments investigation. It is not reported as fixed or as a measured GPU bottleneck. Existing SDK build-number and RealityKit internal diagnostics also remain visible.

Latest source Release archive `.build/ECONOPOLIS-Final.xcarchive`: **exit 0**, platform IOS, minimum 18.0, SDK 27.1. Final standalone simulator relaunch without test arguments succeeded: `org.econopolis.app: 86657`. The complete source handoff excludes generated build products; the unsigned archive remains local under `.build/`.

Curated screenshots in `docs/Screenshots/` include the actual 3D city, banking heatmap, calculated comparison, citizen inspector and offline explanation. Final full-run attachments are retained in `.build/final-acceptance-attachments/`; earlier captures are identified in their README. No physical-device FPS, signing, IPA export or TestFlight upload has been verified.

Viewer correction discovered during user handoff: Xcode 27's Device Hub is installed at `/Applications/Xcode.app/Contents/Applications/DeviceHub.app` and replaces Simulator.app. Earlier statements about the missing normal Simulator GUI path should not be read as absence of a device viewer. Open Device Hub through Xcode's Open Developer Tool menu, or Run the project with an iPhone destination. Accessibility automation is disabled on this host, so we could not drive Device Hub's controls directly; the actual XCTest results remain unchanged.

## Apple-native UI refresh verification

This is a later presentation-only update; the 47-test combined-phase result above is historical evidence from before the refresh. No economic core source under `Packages/EconopolisCore` changed.

- Debug iPhone Simulator build succeeded (`.build/native-ui-build.log`).
- Native Light/Dark screen verification passed across all five tabs (`.build/NativeAppearanceVisuals.xcresult`, one UI test). Ten actual captures are published under `docs/Screenshots/NativeUI/`.
- Seven existing presentation/playback tests passed during the targeted integration checks.
- The complete bank-run, day-seven warmup, rewind, liquidity replay, citizen inspection and economist response UI case passed separately in `.build/NativeDemoFocused.xcresult` (exit 0).
- Early integrated UI attempts did not pass: native Simulator hit-point lookup sometimes returned unusable locations, and the old helper scrolled a lazy list away while waiting for an asynchronous demo label. The helper now taps the control's actual visible frame and waits for demo state changes before scrolling. Native tab `isSelected` is not used as an assertion because this runtime did not consistently expose that attribute; real destination content is asserted instead.
- The economist now scrolls its real answer into view. Its query, validation and financial calculations remain unchanged.

Final complete UI rerun and latest release archive outcomes are recorded below when finished. Earlier failed/canceled attempts are not represented as passing runs. Apple guidance and design choices are linked in `IOS_DESIGN_SYSTEM.md` and `APPLE_UI_REFRESH.md`.

### Final native appearance and stocks result

`.build/NativeUIFinal.xcresult`: **5 UI tests passed, 0 failed**, after the native visual refresh. This includes all five destinations in Light/Dark, the complete calculated demo, filters, previews, camera gestures and existing navigation checks.

`.build/StocksNativeFinal.xcresult`: **22 passed, 0 failed, 0 skipped** on iPhone 17 / iOS 27.0 after adding the optional stock-reference feature: **16 hosted tests** (9 market-data, 5 presentation, 2 playback) and **6 UI tests**, including the no-key market setup and cancellation flow. Test operation: 271.945 seconds. One internal QoS priority-inversion warning remains visible; no device performance fix or FPS claim is inferred.

Actual command:

```sh
xcodebuild -quiet -project Econopolis.xcodeproj -scheme Econopolis -configuration Debug -derivedDataPath .build/ios -destination 'platform=iOS Simulator,id=BD53D5D9-F086-4961-AE37-EAE90C04684E' -parallel-testing-enabled NO -only-testing:EconopolisUITests -only-testing:EconopolisAppTests/MarketDataTests -only-testing:EconopolisAppTests/Phase2PresentationTests -only-testing:EconopolisAppTests/PlaybackTests -resultBundlePath .build/StocksNativeFinal.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

Local Simulator signing is important for generated application-identifier/Keychain entitlements. The initial unsigned market test run passed eight cases and failed secure storage; rerunning with correct local signing passed all nine, without insecure storage fallbacks. A zero-test filter attempt is not counted as verification. Keychain tests use an isolated service and UI tests use a separate namespace; no real provider key was used.

Authenticated live quotes remain **unverified**. A single anonymous production GET returned HTTP 400 with Binance code -2014. Client fixtures are test-only, never shown as live prices. The stock screen requires a valid user-supplied provider key and product access; it cannot fabricate data when access is missing.

Current actual native captures are in `docs/Screenshots/NativeUI/`, exported from the passing 22-test result bundle. They include Light/Dark tabs and the empty secure-connection flow. The original combined-phase 47-test result and 32 portable-core tests above remain historical financial-regression evidence; the economic core was not changed for either later feature.

Final credential lifecycle audit: an additional race test verifies that a refresh cannot reload the old Keychain value while disconnection is deleting it. `.build/StocksCredentialFinal.xcresult`: **11 passed, 0 failed, 0 skipped**, including **10 market client/storage/lifecycle tests** and the actual no-key connection/cancel UI case. No runtime warnings were reported in this focused run. This followed the 22-test integration run; their overlapping cases are not summed as unique test coverage. The native UI and economic core were unchanged by the final lifecycle guard.

Latest source unsigned device archive: `.build/ECONOPOLIS-Current.xcarchive`, Release generic iOS destination, **exit 0** after the credential deletion guard. Device signing/provisioning, authenticated Binance quotes and TestFlight remain unverified.

```sh
xcodebuild -quiet -project Econopolis.xcodeproj -scheme Econopolis -configuration Release -derivedDataPath .build/release -destination 'generic/platform=iOS' -archivePath .build/ECONOPOLIS-Current.xcarchive CODE_SIGNING_ALLOWED=NO archive
```
