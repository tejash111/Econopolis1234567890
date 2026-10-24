# ECONOPOLIS architecture

The application is iPhone-only, Swift 6, iOS 18+, with no backend or AR permission. The portable core can be tested on the development host; it is not a macOS app.

## Ownership

`SimulationEngine` is the authoritative economic actor. It owns the complete Codable state, SplitMix64 RNG, event pipeline and integer-cent ledger. `CrisisEngine` supplies typed hooks to that pipeline. `BranchSession` coordinates two independent engine actors and a bounded pair of demo checkpoints. Financial state is never shared mutably between worlds.

`SimulationViewModel` is observable and main-actor isolated. One cancel-and-join command task serializes playback, reset, scenario commands, replay and saving; revision checks discard stale results. Normal playback publication is limited to four times per second. Demo batch runs publish intermediate progress every four simulated days. They use the same actor commands, not a second playback clock.

SwiftData stores versioned Codable `SessionArchive` payloads, including A/B snapshots, configuration/events, recorded metrics, demo checkpoint/future and selected world. Pause/background and command completion save the current session. Background execution has a bounded system task; foreground can resume playback. Corrupt archives surface recovery choices rather than being silently deleted.

## Presentation

Native TabView hosts City, Economy, Crisis Lab, Citizens and AI Economist. NavigationStack and sheets provide typed entity IDs and financial inspection. `CityProjectionService` creates read-only snapshots outside the main actor, mapping real entities to deterministic procedural lots. RealityKit coordinator caches meshes/materials, preserves camera state, applies changed statuses and bounds activity markers/flows. ScenePhase removes expensive 3D rendering while inactive; memory warnings select the Canvas renderer.

Charts are derived from recorded history, never generated from the current value. Currency inputs parse decimal cents. Currency balances remain integer cents. List/search profiles and inspectors read actual entity/evidence queries. Offline intent interpretation produces validated typed plans and opens a confirmation form; it never bypasses engine validation.

## Source layout

- `Packages/EconopolisCore/Sources/EconopolisCore`: Models, Generation, Ledger, Simulation, Economy, Metrics, Crisis.
- `EconopolisApp/City`: read-only projection/layout, RealityKit scene/camera/resources, Canvas fallback.
- `EconopolisApp/Views`, `Components`, `Presentation`: navigation, sheets, native charts, glass styling, settings/export and formatting.
- `EconopolisApp/ViewModels`, `Persistence`: serialized UI commands and local SwiftData archives.
- `EconopolisAppTests`, `EconopolisUITests`, package tests: financial, branch, presentation, lifecycle and actual iOS interaction checks.

The Xcode hosted test target references shared core test sources directly. Keep static linkage and explicit framework runpaths; a second dynamically linked copy previously prevented standalone launch.

Further details: [iOS UI](IOS_UI_ARCHITECTURE.md), [economic model](ECONOMIC_MODEL.md), [crises](CRISIS_ENGINE.md), [time travel](TIME_TRAVEL.md), [AI](AI_ECONOMIST.md).
