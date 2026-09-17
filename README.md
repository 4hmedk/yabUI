# yabUI

<p align="center">
  <img src="yabUI/Resources/yabUI.png" width="128" alt="yabUI icon">
</p>

<p align="center"><strong>A visual command center for macOS window management.</strong></p>

<p align="center">
  <a href="https://github.com/4hmedk/yabUI/releases/latest">Download</a>
  · <a href="https://github.com/4hmedk/yabUI/releases">Releases</a>
  · <a href="yabUI/README.md">Build from source</a>
</p>

## Overview

yabUI turns spaces, displays, and windows into a compact native macOS surface.
The main app gives you a live workspace map; the menu-bar surface keeps the
same essentials available without opening a terminal or a large window.

The interface is designed around the way a desktop actually feels:

- a unified window map with proportional, non-overlapping tiles
- app icons instead of noisy window-name lists
- click-to-focus behavior for every visible window
- drag-and-drop movement, swapping, splitting, and rebalancing
- reorderable spaces across displays
- a prominent service control in both the app and menu bar
- a transparent activity log for every command sent by the app

## Install

Download the latest `yabUI.dmg` from the [release page](https://github.com/4hmedk/yabUI/releases/latest), open it, and drag `yabUI.app` to Applications.

The app includes a universal window-manager runtime, so a separate command-line
installation is not required. macOS Accessibility permission is required for
window control. Advanced space operations may require the same scripting
permissions as the underlying runtime.

## The app surface

### Overview

The Overview tab shows service health, quick layout controls, recent activity,
open applications, and one unified map of visible windows. A tile keeps the
window's approximate size and layout relationship while remaining readable at
compact sizes.

### Workspace

Workspace is the full editing surface. Drag a window onto another tile:

- center — exchange positions
- left/right/top/bottom — split into that direction
- another space — move the window there

Spaces can be dragged to reorder them or move them between displays. The app
rebalances affected spaces after a move so empty gaps do not linger.

### Menu bar

The menu-bar item opens a proper yabUI surface rather than a plain command menu.
It includes:

- play/pause-style start and stop control
- restart and refresh
- a live compact window map
- click-to-focus tiles
- drag-to-move and drag-to-split tiles
- balance, float/tile, zoom, and rotate actions

## Build

Requirements: Apple Silicon macOS 26 or newer, Xcode command-line tools, and a
working local checkout of this repository.

```sh
./yabUI/scripts/build_app.sh
./yabUI/scripts/package_dmg.sh
```

Build output is written to `yabUI/dist/`. The build script embeds the universal
runtime found at `/opt/homebrew/bin/yabai`, `/usr/local/bin/yabai`, or
`/usr/bin/yabai`; set `YABAI_BIN` to override that path.

## Repository layout

| Path | Purpose |
| --- | --- |
| `yabUI/Sources/yabUI/` | SwiftUI application source |
| `yabUI/Resources/` | App metadata and icon |
| `yabUI/scripts/` | App and installer build scripts |
| `yabUI/RELEASE_NOTES_*.md` | Release-specific notes |
| `src/`, `examples/`, `doc/` | The bundled window-manager runtime and its reference material |

## Project lineage

yabUI is distributed in a public fork of the original window-manager project.
The GUI layer is maintained under `yabUI/`; the root license and runtime source
remain available for transparency and reproducible builds.

## License

yabUI and the retained runtime source are distributed under the terms in
[`LICENSE.txt`](LICENSE.txt).
