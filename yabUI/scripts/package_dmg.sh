#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
PROJECT="${ROOT:h}"
APP="$PROJECT/dist/yabUI.app"

if [[ ! -d "$APP" ]]; then
  "$ROOT/build_app.sh" >/dev/null
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$PROJECT/dist/yabUI-${VERSION}.dmg"

STAGE="$(mktemp -d /private/tmp/yabUI-dmg.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/yabUI.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "yabUI" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "$DMG"
