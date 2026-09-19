#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
PROJECT="${ROOT:h}"
REPO="${PROJECT:h}"
DIST="$PROJECT/dist"
OUT="$DIST/yabUI.app"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources" \
  "$OUT/Contents/Resources/yabUI Runtime.app/Contents/MacOS"

SWIFTC="${SWIFTC:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc}"
SDK="${SDK:-/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

for ARCH in arm64 x86_64; do
  "$SWIFTC" "$PROJECT/Sources/yabUI/YabaiControl.swift" -o "$DIST/yabUI-$ARCH" \
    -framework SwiftUI -framework AppKit \
    -sdk "$SDK" \
    -target "$ARCH-apple-macosx26.0" \
    -module-cache-path "/private/tmp/yabui-module-cache-$ARCH" \
    -parse-as-library
done
lipo -create "$DIST/yabUI-arm64" "$DIST/yabUI-x86_64" -output "$OUT/Contents/MacOS/yabUI"
rm -f "$DIST/yabUI-arm64" "$DIST/yabUI-x86_64"

cp "$PROJECT/Resources/Info.plist" "$OUT/Contents/Info.plist"
cp "$PROJECT/Resources/yabUI.png" "$OUT/Contents/Resources/yabUI.png"
cp "$PROJECT/Resources/RuntimeInfo.plist" "$OUT/Contents/Resources/yabUI Runtime.app/Contents/Info.plist"

# Bundle Yabai so the release app can operate without a separate installation.
# A system binary remains a development fallback when explicitly building on a
# machine that does not have Yabai available yet.
YABAI_BIN="${YABAI_BIN:-}"
if [[ -z "$YABAI_BIN" ]]; then
  for candidate in /opt/homebrew/bin/yabai /usr/local/bin/yabai /usr/bin/yabai; do
    if [[ -x "$candidate" ]]; then
      YABAI_BIN="$candidate"
      break
    fi
  done
fi
if [[ -z "$YABAI_BIN" && -x "$REPO/bin/yabai" ]]; then
  YABAI_BIN="$REPO/bin/yabai"
fi
if [[ -z "$YABAI_BIN" ]]; then
  echo "No runtime found; building the bundled runtime from the repository source." >&2
  make -C "$REPO" install
  YABAI_BIN="$REPO/bin/yabai"
fi
if [[ -n "$YABAI_BIN" && -x "$YABAI_BIN" ]]; then
  cp "$YABAI_BIN" "$OUT/Contents/Resources/yabUI Runtime.app/Contents/MacOS/yabai"
  chmod +x "$OUT/Contents/Resources/yabUI Runtime.app/Contents/MacOS/yabai"
else
  echo "error: no bundled runtime was produced" >&2
  exit 1
fi

codesign --force --sign - "$OUT/Contents/Resources/yabUI Runtime.app" >/dev/null
codesign --force --deep --options runtime --sign - "$OUT" >/dev/null
codesign --verify --deep --strict "$OUT"
echo "$OUT"
