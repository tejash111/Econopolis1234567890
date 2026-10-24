# Simulation-to-city architecture

## Ownership and navigation

`SimulationViewModel` remains the sole main-actor presentation/command owner. It serializes initialization, play, pause, step, reset, demo, crisis, policy and enrollment commands. Every replacement cancels and joins its predecessor. Engine calls and snapshot encoding execute on actors away from UI isolation. `AppPreferences` owns rendering/theme settings and camera commands; it never changes money.

The native TabView has City, Economy, Crisis Lab, Citizens and AI Economist. Each detail destination uses a NavigationStack or inspector sheet. Bank/business/district directories and settings are reachable from City and Economy. Stable entity IDs are passed through navigation. Filters, tab selection and navigation stacks remain local UI state across financial refreshes.

## Read-only projections

`SimulationEngine.entities()` returns compact citizen summaries, businesses and actual account-owner mapping. `evidence(id:)` is a read-only actor query for one profile's real household, recent transfers and recorded events. No presentation code directly accesses a mutable ledger.

`CityProjectionService` builds `CityPresentationSnapshot` off the main actor from actual branch summaries. It contains district metrics, deterministic lots, home/work groups and supported posted transfer flows. Full ledger entries, all loan records and all household decisions are not copied every display frame. Publication is coalesced during playback.

`ChartProjection` selects real recorded days and supported metrics. District filtering is exposed only for history fields actually recorded per district. Empty/one-point histories show an honest empty state. There is no invented interpolation.

## Renderer

`RealityCityView` is a supported UIKit bridge for non-AR RealityKit. `CityResources` shares primitive meshes and material recipes. Streets, parks, harbor water, industrial chimneys, bank beacons, offices, universities and residential-density blocks are procedural and offline. Commercial banks lack a domain district field, so Financial Core bank placements are explicitly visual administrative placements, not invented domain relationships.

Geometry IDs map actual businesses and banks one-to-one. Residential blocks group actual district residents and select the district. Density marker groups retain citizen IDs; worker markers derive from real employer districts. Quality limits markers and concurrent transaction animations. No 1,000-view/complex-avatar scene is created.

The coordinator builds terrain only when seed/entity identity changes and updates affected building transforms/health highlights on data changes. Deleted IDs are removed. Scene mutations are main-isolated. Cached camera pose survives tick refreshes and tab reconstruction. ScenePhase removes expensive rendering while inactive; memory warning selects the Canvas fallback.

Posted transfer flows use actual transaction IDs, amounts, days and account-owner lookup. Household endpoints use documented district anchors because routes are absent. Rejected transfers never animate. A watermark prevents replaying old activity; branch switching clears old animations. Concurrent flow count and duration are bounded; cleanup tasks cancel on teardown or Reduced Motion.

## Camera and selection

One-finger drag orbits; two-finger drag pans. Pinch zoom is clamped. Double tap focuses the most recently selected entity or resets framing. A visible viewfinder resets only the camera, independently of economic reset. Tap waits for pan/double-tap/long-press recognition to avoid accidental selection. Long press opens contextual financial details. The directory is the accessible alternative to spatial selection.

## Heatmaps

- Standard: restrained neighborhood architecture.
- Activity: current seller-district consumer spending relative to the busiest district; high/low activity, not an official risk rating.
- Business stress: mean `10000 − financialHealth` for real district businesses.
- Employment: unemployed share of the district labor force, excluding students/retirees.
- Banking stress: modeled funding/settlement stress of banks serving district residents; a descriptive exposure proxy.

Scores are 0...10000. Green is below 3500, amber is 3500...6999, red is 7000+. A visible legend explains the selected mode. Updates follow economic snapshots/settings, not display-frame frequency.

## Deployment and verification

Swift 6, iPhone only, iOS 18 baseline. No camera permission, AR session, backend, paid library or authentication. iOS 26 glass has availability fallbacks. Scene-update CPU time and logical entity counts are measured separately from rendering FPS; neither is a claim of physical-device frame rate. Consult the current test reports for actual destinations, measurements, screenshots and unverified device checks.

The interactive Canvas fallback shares the snapshot and preferences interfaces. It supports touch pan/zoom, entity selection, camera reset/focus and real heatmap colors. It deliberately omits 3D flow particles. Switching equal-day A/B branches invalidates heatmap and density caches so visual state follows the selected world.

## Native appearance update

The default appearance now follows the OS. Semantic UIKit background colors bridge into SwiftUI and RealityKit; blue is the shared interaction/chart accent. Crisis Lab and AI Economist use native inset grouped lists, and root financial destinations use large system navigation titles. The city ground adapts to light/dark settings without resetting the economic state or camera. Accessibility-size metric layouts collapse to one column. See IOS_DESIGN_SYSTEM.md for Apple source references and component conventions.
