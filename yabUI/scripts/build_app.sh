#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
PROJECT="${ROOT:h}"
DIST="$PROJECT/dist"
OUT="$DIST/yabUI.app"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"

SWIFTC="${SWIFTC:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc}"
SDK="${SDK:-/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

"$SWIFTC" "$PROJECT/Sources/yabUI/YabaiControl.swift" -o "$OUT/Contents/MacOS/yabUI" \
  -framework SwiftUI -framework AppKit \
  -sdk "$SDK" \
  -target arm64-apple-macosx26.0 \
  -module-cache-path /private/tmp/yabui-module-cache \
  -parse-as-library

cp "$PROJECT/Resources/Info.plist" "$OUT/Contents/Info.plist"
cp "$PROJECT/Resources/yabUI.png" "$OUT/Contents/Resources/yabUI.png"

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
if [[ -n "$YABAI_BIN" && -x "$YABAI_BIN" ]]; then
  cp "$YABAI_BIN" "$OUT/Contents/Resources/yabai"
  chmod +x "$OUT/Contents/Resources/yabai"
else
  echo "warning: no Yabai binary found; this build requires a system install at runtime" >&2
fi

codesign --force --deep --sign - "$OUT" >/dev/null 2>&1 || true
echo "$OUT"
