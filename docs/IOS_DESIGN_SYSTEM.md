# iPhone design system

The app uses San Francisco typography, system navigation stacks and tab bars, neutral Liquid Glass controls, and native presentation detents. iOS 18 remains the deployment baseline. iOS 26+ uses `glassEffect` and `GlassEffectContainer`; older systems receive material backgrounds. Build with an SDK that contains the glass APIs.

Themes: Dark (default), Light and System. Dark uses graphite/midnight surfaces; Light uses restrained system grouped surfaces. Cyan denotes financial activity/selection, emerald health, amber caution and red actual financial stress. Violet is reserved for the offline economist. Text-heavy cards use opaque/system surfaces instead of layered glass.

Reusable components include `MetricCard`, `PlaybackBar`, `WorldPicker`, `TimelinePanel`, `ComparisonPanel`, `TransactionRow`, `EmptyFinancialState` and the crisis/policy preview forms. Monetary balances remain integer cents; detail views show cents, while compact KPI cards explicitly use abbreviated formatting. `MoneyInput` parses bounded decimal currency without binary floating-point balance arithmetic.

Major actions use approximately 44-point or larger hit regions. Citizen rows have explicit rectangular hit shapes, including whitespace. Search supports explicit keyboard dismissal and native filters. Haptics occur on confirmed/manual interaction, never continuously during playback. Reduced Motion removes transaction-particle animation; camera control remains direct and has no inertial motion.

RealityKit uses a non-AR virtual camera, reused geometry/materials and procedural district architecture. Six neighborhoods use consistent visual identities. Homes/density dots are clearly labeled abstractions of actual residents/workers. Selected/financially stressed institutions receive legible ground highlights. Detail sheets retain current financial state as the simulation updates.

Primary navigation follows the latest combined master directive: City, Economy, Crisis Lab, Citizens and AI Economist. Institution directories, information, settings and reports live inside City search and Economy navigation; the earlier Phase 2-only More tab was superseded.
