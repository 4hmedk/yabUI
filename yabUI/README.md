# yabUI

yabUI is a compact native macOS GUI for Yabai. It provides a visual workspace
map, drag-and-drop window and space management, service controls, layout
commands, and a menu-bar status item.

This directory is the GUI layer in the upstream Yabai fork. The original
Yabai source, documentation, examples, and license remain at the repository
root.

## Build locally

```sh
./yabUI/scripts/build_app.sh
./yabUI/scripts/package_dmg.sh
```

The app is written in SwiftUI and targets Apple Silicon macOS 26 or newer,
matching the upstream source baseline used by this fork. The release build
embeds a universal Yabai executable in the app bundle, so an end user does not
need to install Yabai separately.

Yabai still requires the normal macOS Accessibility permission. Operations
that depend on Yabai's scripting addition may also require the upstream
configuration and SIP guidance described in the root documentation.

## Release contents

- `yabUI.app` — the application bundle
- `yabUI-1.0.0.dmg` — drag-to-Applications installer

The app prefers its bundled `Contents/Resources/yabai` binary and falls back to
common system paths for developer builds.
