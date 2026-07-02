#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/assets/branding/app_icon.svg"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

rsvg-convert -w 1024 -h 1024 "$SVG" -o "$TMP/icon_1024.png"

gen() {
  local size="$1"
  local out="$2"
  rsvg-convert -w "$size" -h "$size" "$SVG" -o "$out"
}

gen 48  "$ROOT/android/app/src/main/res/mipmap-mdpi/ic_launcher.png"
gen 72  "$ROOT/android/app/src/main/res/mipmap-hdpi/ic_launcher.png"
gen 96  "$ROOT/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
gen 144 "$ROOT/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"
gen 192 "$ROOT/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"

gen 16  "$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png"
gen 32  "$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png"
gen 64  "$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png"
gen 128 "$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png"
gen 256 "$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
gen 512 "$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"
cp "$TMP/icon_1024.png" "$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"

gen 192 "$ROOT/web/icons/Icon-192.png"
gen 512 "$ROOT/web/icons/Icon-512.png"
cp "$ROOT/web/icons/Icon-192.png" "$ROOT/web/icons/Icon-maskable-192.png"
cp "$ROOT/web/icons/Icon-512.png" "$ROOT/web/icons/Icon-maskable-512.png"
gen 32 "$ROOT/web/favicon.png"

magick "$TMP/icon_1024.png" -define icon:auto-resize=256,128,64,48,32,16 \
  "$ROOT/windows/runner/resources/app_icon.ico"

echo "Icons generated from $SVG"
