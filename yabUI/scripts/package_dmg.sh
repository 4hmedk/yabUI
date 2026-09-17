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
ZIP="$PROJECT/dist/yabUI-${VERSION}.zip"
CHECKSUM="$PROJECT/dist/yabUI-${VERSION}.sha256"

STAGE="$(mktemp -d /private/tmp/yabUI-dmg.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/yabUI.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "yabUI" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(cd "$PROJECT/dist" && shasum -a 256 "yabUI-${VERSION}.dmg" "yabUI-${VERSION}.zip" > "yabUI-${VERSION}.sha256")
printf '%s\n%s\n%s\n' "$DMG" "$ZIP" "$CHECKSUM"
