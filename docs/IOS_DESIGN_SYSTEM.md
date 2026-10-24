# Native iOS design system

The current visual direction follows Apple's standard iPhone interface conventions. It replaces the earlier forced-dark cyan/violet styling while preserving the real economy, navigation and procedural city.

## Apple references

- [Color — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/color): use semantic, adaptive system colors and reserve status colors for meaningful information.
- [Typography — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/typography) and [System fonts](https://developer.apple.com/documentation/technologyoverviews/fonts): use system text styles that adapt to context, language and Dynamic Type.
- [Materials — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/materials): use glass for controls/navigation and appropriate standard surfaces for content.
- [Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/liquid-glass): retain native component behavior and restrained control colors.

## Color and appearance

| Role | Implementation |
|---|---|
| Default appearance | Follow System; Settings can explicitly choose Light or Dark |
| Screen background | `UIColor.systemGroupedBackground` |
| Content surface | `UIColor.secondarySystemGroupedBackground` |
| Main text | Semantic `.primary` |
| Supporting text | Semantic `.secondary` / `.tertiary` |
| Interactive accent | System `.blue` |
| Healthy financial state | System `.green` |
| Warning / critical state | System `.orange` / `.red` |
| Navigation and floating controls | Neutral native glass or system materials |

RealityKit resolves its scene background against the active appearance. Light mode uses pale district ground surfaces; dark mode uses subdued surfaces. Appearance changes update scenery without rebuilding financial state or resetting the camera. Building colors distinguish actual district content; they are not app navigation colors or invented financial ratings.

## Typography

SwiftUI system text styles supply San Francisco and Dynamic Type: native large navigation titles, `.title2`/`.headline` for financial hierarchy, `.body` for primary rows and explanations, `.subheadline` for supporting content, and `.caption` for provenance/secondary metadata. Numeric values use tabular digits while retaining the system font. No custom font package or artificial logo letter-spacing is used.

Metric cards switch to one column at accessibility text sizes. This is an adaptation, not a claim that a complete device accessibility audit has passed.

## Components and screens

- Native `TabView`, `NavigationStack`, searchable lists, sheets, menus, pickers and forms remain authoritative.
- Crisis Lab uses inset grouped sections, full-width scenario/policy rows, supporting descriptions and a standard prominent blue demo action.
- AI Economist uses grouped composer, evidence and suggested-question sections. Responses use body text on semantic content surfaces.
- Economy uses blue charts, white/elevated semantic metric surfaces and native large-title navigation.
- Citizens uses standard grouped rows, blue identity accents, semantic financial text and existing search/filter sheets.
- City preserves the explorable 3D scene, with a compact system-font identity, blue controls, segmented world picker and neutral playback glass.
- Glass is availability-gated at iOS 26; older supported versions use system material. Text-heavy financial content is not wrapped in multiple glass layers.
- Full-row rectangular hit areas include empty spacer regions. Primary actions retain at least 44-point touch targets.

Reduce Motion, haptic preferences and ScenePhase behavior remain in place. View styling never posts transactions or changes simulation outcomes. Test reports distinguish actual Simulator screenshots and interaction checks from physical-device performance/accessibility work that is still unverified.
