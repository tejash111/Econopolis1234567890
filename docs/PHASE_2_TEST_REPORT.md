# Phase 2 verification

The combined sprint completes the native city/presentation work while extending crises, branches and offline commands. Final shared results are recorded in [TEST_REPORT.md](TEST_REPORT.md).

## Environment and initial audit

macOS 27.0.1, Apple Silicon MacBook Air, Xcode 27.1, Swift 6.4, iOS SDK 27.1. Existing Xcode project and static core linkage retained. iPhone-only iOS 18 deployment baseline retained. `AGENTS.md`, README, architecture and ledger were inspected; baseline source and economic hashes were backed up under `.build/phase2-audit/`. There is no Git metadata in this repository.

Baseline iOS build passed. The user explicitly declined a Phase 1 test rerun before implementation; integrated regression tests were run later under the combined master directive.

## Actual targeted verification

- `.build/Phase2ProjectionTests.xcresult`: **8 passed, 0 failed**, presentation/intent/player tests, iPhone 17 iOS 27.0. Projection checks actual bank/business IDs, complete resident coverage, deterministic seeded layouts, real posted flows, bounded heatmap values, chart history, entity filters, invalid camera values and reset consistency.
- `.build/CombinedDemoUIFixed.xcresult`: **2 passed, 0 failed**, actual XCTest touch interactions. Verified camera drag/pinch/reset, heatmap menu, filters, empty search, command preview cancellation and complete bank-run/rewind/rescue/citizen/offline explanation journey.
- Initial UI tests found non-hittable citizen row spacers and a keyboard blocking tab changes. Rows now use a rectangular hit shape; search submission dismisses the keyboard. The corrected tests passed.

Actual screenshots were retained in result bundles and exported to `.build/combined-fixed-attachments/`. Final curated images are in `docs/Screenshots/`. They are rendered simulator captures, not mockups.

## Rendering and visual limits

RealityKit runs in non-AR mode with a virtual camera; no camera permission or AR tracking is needed. Six procedural neighborhoods, shops, factories, offices, bank beacons, residential density groups, roads, parks and harbor water are visible. Materials/meshes are shared; status changes update existing entities. Touch camera state survives economic updates and tab changes. Canvas provides pan/zoom/selection, focus/reset and financial heatmap colors; it omits RealityKit transaction-particle animation.

No physical-iPhone FPS, GPU, power or memory profile was measured. In-app diagnostics report CPU scene-update wall time and logical entity counts only. Physical touch feel, iOS 18 material appearance, VoiceOver, large accessibility sizes and landscape screenshots require additional device verification. A headless Simulator automation path was available; the standalone Simulator GUI application was not installed at its normal Xcode path.

Final combined acceptance `.build/FinalAcceptance.xcresult`: **47 passed, 0 failed, 0 skipped**, including all four UI tests. Policy, district, activity and economist row hit areas now include their full rectangular labels. Equal-day branch switches refresh district heatmaps and density markers. The final runtime QoS warning and physical-device limitations are recorded in TEST_REPORT.md.
