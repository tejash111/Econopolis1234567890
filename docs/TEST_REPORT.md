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

`.build/FinalAcceptance.xcresult`: **PASS — 47 passed, 0 failed, 0 skipped**, iPhone 17 / iOS 27.0. Xcode test operation: 258.084 seconds, including setup/automation. Hosted tests: **43 passed**, eight suites, 79.122 seconds. All **four actual UI tests passed**, including the corrected full-width policy row and complete Great Bank Run journey. Exit code 0. No subsequent source edits were made after this successful run.

Final iOS simulator Debug benchmark: 90 days / 1,000 citizens in **7.622169708 seconds**, 194,582 settled transactions. Final iOS 365-day shock run: **31.616810917 seconds**, 750,106 settled transactions. These are simulator wall times on this development host, not real-device FPS or energy measurements.

The result bundle contains **one runtime QoS priority-inversion warning** during `MobileNavigationTests.testCityTouchAndFallback()`, with no source location. It did not fail the test; its source and device impact require Instruments investigation. It is not reported as fixed or as a measured GPU bottleneck. Existing SDK build-number and RealityKit internal diagnostics also remain visible.

Latest source Release archive `.build/ECONOPOLIS-Final.xcarchive`: **exit 0**, platform IOS, minimum 18.0, SDK 27.1. Final standalone simulator relaunch without test arguments succeeded: `org.econopolis.app: 86657`. The complete source handoff excludes generated build products; the unsigned archive remains local under `.build/`.

Curated screenshots in `docs/Screenshots/` include the actual 3D city, banking heatmap, calculated comparison, citizen inspector and offline explanation. Final full-run attachments are retained in `.build/final-acceptance-attachments/`; earlier captures are identified in their README. No physical-device FPS, signing, IPA export or TestFlight upload has been verified.

Viewer correction discovered during user handoff: Xcode 27's Device Hub is installed at `/Applications/Xcode.app/Contents/Applications/DeviceHub.app` and replaces Simulator.app. Earlier statements about the missing normal Simulator GUI path should not be read as absence of a device viewer. Open Device Hub through Xcode's Open Developer Tool menu, or Run the project with an iPhone destination. Accessibility automation is disabled on this host, so we could not drive Device Hub's controls directly; the actual XCTest results remain unchanged.
