# ECONOPOLIS implementation status

Updated 2026-10-24. The authorized combined scope extends Phase 2 through Phases 3–5. **Functional offline hackathon implementation; release verification remains partial.** No macOS/Catalyst target or external backend is present.

## Delivered functionality

| Area | Status | Actual implementation |
|---|---|---|
| Original financial foundation | Implemented | Deterministic 1,000 citizens / 80 firms / 4 banks / 6 districts; integer ledger, actual spending/payroll/loans/defaults and metrics. Original core regression retained. |
| Native iPhone city | Implemented | Non-AR RealityKit, six procedural neighborhoods, stable bank/firm mappings, shared meshes/materials, streets/parks/harbor, touch orbit/pan/zoom/focus/reset/selection, economic heatmaps, grouped real residents and bounded posted-transfer flows. |
| Mobile financial experience | Implemented | Five native tabs, Swift Charts/history filters, searchable citizens and institution directories, complete supported financial fields, linked inspectors, settings and theme/quality controls. |
| Bank run and propagation | Implemented with documented simplification | Actual cash conversions and accessible bank settlement capacity, rejected/queued payments, linked cash-flow effects, observational employment/default evidence and scoped disruption records. No custody-deposit destruction or fabricated insolvency. |
| Other crises | Implemented | Temporary rate shock, layoffs by district/industry, recession, credit crunch and scoped payment outage/recovery. Common typed event validation and economic hooks. |
| Public policies | Implemented | Issued repayable central-bank liquidity, time-limited guarantee, policy rate, treasury-funded household relief and funded business credit. Editable/cancelable previews and actual accounting. |
| Rewind and comparison | Implemented | Independent A/B actors, complete versioned Codable snapshots, deterministic event replay and keyed comparable random draws after branch commands; same-day comparisons and same-citizen differences. |
| Great Bank Run demo | Implemented / simulator-tested | Seed 2026, day-seven checkpoint, 28-day crisis, recorded World A, rewind B, explicitly funded rescue replay and computed comparison. No fixed favorable results. |
| Offline economist | Implemented | Deterministic parsing, numerical/target validation, confirmation-required scenario previews and evidence-based explanations. No cloud or key. |
| Foundation Models | Not implemented | Optional compatible-device inference is absent. The working deterministic fallback is explicitly labeled. |
| Citizen stories / enrollment | Implemented | Actual decision/event/transaction evidence, branch comparison; fictional player creates a new shared 1,001-citizen baseline with treasury-funded starting adjustment. No invented biography/history. |
| Local persistence | Implemented | SwiftData versioned archives include branch events, snapshots, demo checkpoints and metadata; autosave, ScenePhase pause/resume, cancellation/revision guards and corrupt-save recovery. |
| Exports | Implemented | Real metric CSV, World A configuration JSON and comparison JSON, native share links. Export requires a stable paused state. |
| Glass / accessibility | Implemented; device audit partial | iOS 26 native glass and iOS 18 material fallback, dark/light/system, native sheets/tabs, accessible controls, Dynamic Type and Reduce Motion. Full physical-device VoiceOver/large-text audit unverified. |
| Release packaging | Locally archived; distribution blocked | Unsigned generic-iPhone Release archive built. Signing credentials, physical device and TestFlight upload are not available/verified. |

## Verification and evidence

See [TEST_REPORT.md](TEST_REPORT.md) for exact executed commands, counts, benchmarks, failures/fixes and remaining checks. The original baseline build passed before extension; the user declined an initial Phase 1 test rerun. Integrated financial/UI regressions were run later under the combined directive.

- Core financial, determinism, enrollment and parser tests pass, including a standard-population 365-day shock run.
- Actual iPhone 17 / iOS 27.0 UI automation passed the new complete bank-run/rewind/rescue/citizen/offline-explanation journey.
- Release archive: `.build/ECONOPOLIS-Final.xcarchive`, unsigned iOS 18+ executable, SDK 27.1. No IPA distribution or upload is claimed.
- Final integrated regression: **47 passed, 0 failed, 0 skipped** in `.build/FinalAcceptance.xcresult`, including all four native UI interaction tests. An outdated test label and a real policy-row spacer hit-area bug were fixed before this clean run.

## Practical limitations

The economic model uses custody deposits and funded credit, not calibrated real-world bank mechanics. Operational resolution is distinct from insolvency; liquidity, repeated unmet attempts, public claims and true losses are not interchangeable. Causal journals label observations rather than asserting that every concurrent layoff was caused by a crisis. No physical asset markets, collateral auctions, interbank contagion market or deposit haircut mechanism is claimed.

Full ledger journals grow over time; the causal journal is bounded to 600 and the demo checkpoint set is bounded, but arbitrary multi-year low-memory operation is not guaranteed. Generic rewind recomputes from configuration. World switching uses cached read-only snapshots; economic states remain independent. Canvas has focus/reset/heatmap and pan/zoom/selection but omits animated transaction particles.

Physical iPhone execution, actual FPS/energy/peak-memory measurements, iOS 18 runtime behavior, landscape screenshot quality and a comprehensive accessibility audit remain unverified. Xcode 27.1 prints an SDK build-number parsing warning and RealityKit simulator shader/environment diagnostics; these did not prevent rendering or the verified builds/tests. This educational synthetic economy must not be marketed as forecasting real policy or markets.

Final portable core result: **32 tests passed**. Final simulator benchmarks: 90 days **7.622169708 s** / 194,582 settled transfers; 365 days with shocks **31.616810917 s** / 750,106 settled transfers. No real-device FPS is claimed. One runtime QoS priority-inversion warning during the touch/fallback test remains for Instruments profiling; no source location was supplied.

## Native iOS visual refresh

The UI now defaults to System appearance, uses semantic grouped backgrounds/content surfaces and system blue interactions/charts, and retains native dynamic system typography. Crisis Lab and AI Economist use inset grouped sections; City uses a compact title and neutral floating controls. The 3D ground adapts to appearance without resetting camera or economic state. Metric cards adapt to accessibility text sizes. Economic core source is unchanged. Apple references are recorded in IOS_DESIGN_SYSTEM.md; this refresh's build and targeted UI results are recorded separately in TEST_REPORT.md.

## Optional Live Crypto — CoinGecko Demo

The Binance stock connection has been replaced at the user's request. Economy → Live Crypto now resolves catalog IDs and batches up to eight crypto observations: USD price, 24-hour percentage change, market cap, volume, actual seven-day sparkline samples and provider timestamps. Foreground polling runs once per minute with a shared three-second request gate, rate-limit backoff, cancellation/revision guards and dedicated Demo Keychain credentials. Simulation/core source is unchanged.

Verification: `.build/CoinGeckoVerified.xcresult` **12 passed, 0 failed, 0 skipped** on iPhone 17 / iOS 27.0 (11 hosted client/storage/lifecycle tests, one actual connection/cancel UI test). Debug iOS Simulator test build and generic-iOS Release build both exited 0. Screenshots were captured and visually inspected; setup and cancellation preserve city day zero. A first run caught incorrect optional-field mapping for digit-containing JSON fields; explicit JSON CodingKeys fixed it before the passing run.

Authenticated production access verified on 2026-10-24: the saved simulator Keychain credential received HTTP 200 for coins/list and coins/markets, with three decoded observations and prices. Fixed a production-catalog issue: four entries had empty ticker symbols and incorrectly caused the entire 22,461-entry catalog to be rejected. Incomplete entries are now omitted. The credential is not embedded, logged or committed. Test fixtures do not appear in app UI. Physical-device behavior and FPS are not measured. See LIVE_CRYPTO.md and TEST_REPORT.md for exact commands and limitations. The older `.build/ECONOPOLIS-Current.xcarchive` predates this replacement; current source's Release build is `.build/coingecko-release` and is unsigned, not a distributable archive or TestFlight upload.

Catalog fix follow-up: `.build/CoinGeckoCatalogFix.xcresult` passed **12 market-data regression tests, zero failures/skips**. Updated Debug Simulator app and generic-iOS Release build both succeeded; the corrected app was installed and relaunched. Authenticated API results and the added incomplete-listing regression are recorded in TEST_REPORT.md.
