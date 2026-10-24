# Separate native macOS app

The explicit later user request adds a Mac companion; it supersedes the earlier prohibition on Mac targets for this separate app. The iPhone target remains iPhone-only.

## Reuse and scope

- Xcode project: `Econopolis.xcodeproj`; new scheme/target: `EconopolisMac`.
- Native macOS 15+, Swift 6, bundle `org.econopolis.mac`, no Catalyst.
- Shares the existing EconopolisApp source tree, static EconopolisCore, session coordinator, playback/branch owner, SwiftUI financial screens, crisis demo, citizen directories, metrics/charts, export and optional online clients. No duplicated engine or second codebase.
- Uses native RealityView with the same CitySceneController and CityResources as the iPhone ARView: identical procedural lots, building meshes/facades, terrain, streets, trees, harbor, banks, heatmap tiles, density markers, selection halos and bounded posted-transfer particles. Mouse drag orbits, Shift-drag pans, pinch zooms and clicking selects. Canvas remains an explicit fallback, not the Mac default.
- Uses the existing iPhone SwiftUI screens and floating city controls, with a matching bottom Liquid Glass tab group on Mac rather than a default top tab strip. Cached NSHostingViews preserve destination state. Standard window/control colors and system fonts, 1180×840 default window, minimum 980×720. ⌘1–⌘5 select destinations. Native screen wrappers preserve scene phase and appearance from the shared root.
- iOS haptic/background task/memory-warning handling stays platform guarded. Renderer quality, actual transaction flows and fallback controls work against the shared renderer on both platforms.
- SwiftData store: `~/Library/Application Support/ECONOPOLIS-Mac/session.store`. The Mac does not load/overwrite simulator sessions.
- Mac Keychain service names derive from `org.econopolis.mac`; credentials are separate from iPhone/simulator. No shared project key is embedded or shipped. Existing connection sheets allow local setup.

## Build and run

```sh
xcodebuild -quiet -project Econopolis.xcodeproj -scheme EconopolisMac -configuration Debug -derivedDataPath .build/mac -destination 'platform=macOS,arch=arm64' CODE_SIGN_IDENTITY=- build
open .build/mac/Build/Products/Debug/EconopolisMac.app
xcodebuild -quiet -project Econopolis.xcodeproj -scheme EconopolisMac -configuration Release -derivedDataPath .build/mac-release -destination 'platform=macOS,arch=arm64' CODE_SIGN_IDENTITY=- build
```

These commands were executed successfully on the Apple Silicon host with Xcode 27.1 and macOS SDK 27.0. The initial Debug process launched (PID 79095). The updated shared-3D/UI build was launched separately (PID 94483) with an in-memory session because the original instance declined the automatic quit event. No force quit was used. `Info.plist` confirms MacOSX platform, separate executable/bundle and Mac app icon. This is local ad-hoc signing, not Developer ID distribution or notarization.

The desktop screenshot command returned “could not create image from display”; window enumeration returned no accessible app window. Therefore screenshots, visual layouts, menu/mouse/trackpad interactions, restored sessions and live cloud connections have **not** been verified in the Mac window. The verified iPhone tests use the same shared financial/AI presentation code but do not replace these Mac-specific checks.

## Manual Mac checklist

Open from Xcode/My Mac or Finder, verify the five tabs, drag/pinch/select the city, advance/pause/reset, run The Great Bank Run, inspect entities and charts, save/reopen a session, then optionally connect market/AI credentials. Check window resizing, dark/light appearance, keyboard search and share links. No Mac FPS/battery/memory measurements or signed release distribution are claimed.
