# ECONOPOLIS conventions — iPhone directive

The mandatory iOS-only directive supersedes the original desktop specification. This repository ships an **iPhone-only iOS 18+ SwiftUI application**, with no macOS or Catalyst application target. The Swift package retains a macOS library platform only to permit independent host core tests; host tests do not validate the iPhone app.

Preserve the offline, fictional educational model. Never describe it as predicting markets or real policy outcomes. The current authorized scope includes completed foundations plus combined Phases 2–5. Preserve working behavior; do not claim distribution milestones without verification.

- Statically link the core into the iPhone app. Hosted tests resolve its symbols through the app; do not add a second dynamic package consumer. Keep embedded-framework runpaths explicit and verify standalone launch after packaging changes.
- Swift 6 strict concurrency, SwiftUI, Foundation, RealityKit, Charts, and SwiftData. No mandatory network/backend or package downloads.
- The five tabs are City, Economy, Crisis Lab, Citizens, and AI Economist. Use sheets and navigation stacks, 44pt+ actions, safe areas, VoiceOver labels, Dynamic Type, and touch controls. Do not reintroduce desktop toolbars, hover, sidebars, or multiwindow UI.
- Gate Liquid Glass at iOS 26. No AR session/camera permission. Use shared meshes/materials, a limited number of institution entities, and Canvas fallback. No 1,000-view citizen render tree or per-citizen LLM calls.
- Economic state belongs to `SimulationEngine` actors. `BranchSession` coordinates independent A/B engines through one serialized command owner. Preserve each branch's seed, RNG, ordered events, and finances. Playback advances both days together; timeline replay applies each branch's own events.
- Main-actor presentation publishes at most four times per second during playback. Cancel and join replaced commands; revision-check results after awaits. Pause and save on background, remove RealityKit when inactive, and switch to Canvas on memory warning. Never run economic ticks or snapshot encoding on the main actor.
- SwiftData stores versioned Codable session archives. Dates are storage metadata only. Do not erase invalid saves automatically; explicit Reset can replace an unreadable session.
- Money is Int64 cents, economic ratios are integer basis points. Route all changes through the ledger, reject unaffordable transfers, and preserve opening allocations and complete audit journals.
- Bank reserves, deposit liabilities, funded credit claims, and equity are distinct. Never add reserve assets to deposits when measuring the spendable monetary pool. Funding stress is not regulatory capital adequacy.
- Determinism uses SplitMix64, stable IDs, stable arrays, simulation days, and integer decision factors. Never use clocks, UUIDs, system randomness, or dictionary order to choose economic outcomes. Explicit Regenerate may choose a new displayed seed.
- Preserve reconciliation, replay, default, and 90-day tests. Core tests are referenced directly in the iOS hosted test target, without duplicating their source. UI tests cover actual touch navigation and renderer switching.
- AI Economist uses a deterministic offline intent parser, evidence explanations and confirmed typed command previews. If Foundation Models is added, gate device/model availability and preserve this offline fallback. LLM output must never alter deterministic financial decisions implicitly.

Verification from the project root:

```sh
xcrun simctl list devices available
xcodebuild -project Econopolis.xcodeproj -scheme Econopolis -configuration Debug -derivedDataPath .build/ios -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
# Replace SIMULATOR_ID with an available iPhone simulator UUID:
xcodebuild -project Econopolis.xcodeproj -scheme Econopolis -configuration Debug -derivedDataPath .build/ios -destination 'platform=iOS Simulator,id=SIMULATOR_ID' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
# Additional platform-independent library verification only:
swift test --package-path Packages/EconopolisCore --scratch-path .build/core
```

Use actual iOS destinations for app verification. If no runtime exists, `xcodebuild -downloadPlatform iOS -buildVersion VERSION -architectureVariant arm64` installs an explicitly selected Apple runtime. Inspect its supported device types before creating a simulator. On this host iOS 27.1 is Duo-only; iOS 27.0 provides conventional iPhones. Do not download all runtime versions unnecessarily.

Report measured simulator/core timings with configuration and hardware context; never invent real-device FPS/battery results. Physical iPhone checks require a connected device. Unsigned release archiving is authorized; signing/TestFlight require available credentials and permissions; do not claim an upload without verification. Keep `docs/IMPLEMENTATION_STATUS.md` current with actual command results and limitations.

Xcode 27 viewer correction: use `/Applications/Xcode.app/Contents/Applications/DeviceHub.app` (Device Hub), not the removed Simulator.app. Open via Xcode → Open Developer Tool → Device Hub. Running from Xcode with an iPhone destination opens its device window. `simctl launch` alone does not ensure a visible device window. Accessibility automation is disabled on this host; do not claim GUI tools are missing merely because the old Simulator app path is absent.

Current user-approved UI direction follows Apple-native iOS appearance: default to System, use system grouped backgrounds/content surfaces, semantic text colors, standard SwiftUI text styles and system blue interactions. Use green/amber/red only for meaningful financial status. Prefer native grouped sections for forms and directories; keep glass on navigation/floating controls. Avoid forced-dark/neon themes, custom typefaces and letter-spaced product headings. Apple references and implementation choices are in docs/IOS_DESIGN_SYSTEM.md.

Optional Live Stocks is separate from the deterministic economy. It uses only exchangeInfo/quote HTTPS GET requests to api.binance.com, a user-entered Keychain API key, bounded foreground polling and sanitized errors. Never place orders or accept provider legal terms from this feature. Never store API keys in source, UserDefaults, snapshots or exports. Keep Simulator signing enabled (CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-) for Keychain entitlement generation; device archives can compile unsigned but cannot be distributed/run on devices without proper signing. UI tests use an isolated Keychain namespace. See docs/LIVE_STOCKS.md.
