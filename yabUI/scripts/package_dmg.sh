#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
PROJECT="${ROOT:h}"
APP="$PROJECT/dist/yabUI.app"
DMG="$PROJECT/dist/yabUI-1.0.0.dmg"

if [[ ! -d "$APP" ]]; then
  "$ROOT/build_app.sh" >/dev/null
fi

STAGE="$(mktemp -d /private/tmp/yabUI-dmg.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/yabUI.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "yabUI" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "$DMG"
