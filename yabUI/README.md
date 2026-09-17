# yabUI application layer

This directory contains the native SwiftUI app and its release tooling.

## Build

```sh
./yabUI/scripts/build_app.sh
./yabUI/scripts/package_dmg.sh
```

The scripts create `yabUI.app` and a drag-to-Applications DMG in `yabUI/dist/`.
The app bundle includes a universal runtime, so users do not need a separate
terminal installation. Set `YABAI_BIN` when building with a custom runtime.

## Source map

- `Sources/yabUI/YabaiControl.swift` — app, menu-bar surface, workspace map,
  drag/drop interactions, service controls, and activity log
- `Resources/Info.plist` — bundle metadata and version
- `Resources/yabUI.png` — app icon
- `scripts/build_app.sh` — compile and bundle
- `scripts/package_dmg.sh` — create the installer image

## Runtime permissions

macOS Accessibility permission is required for window actions. Space operations
that depend on elevated scripting support may require additional system setup.
The app reports command failures in its Activity tab so configuration issues
remain visible instead of looking like silent UI failures.
