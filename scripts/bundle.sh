#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

# The `swift` on PATH on this machine is a swiftly toolchain that fails against the Xcode SDK. `xcrun` resolves the
# toolchain from the active developer directory instead of PATH. Set DEVELOPER_DIR to build with another Xcode.
xcrun swift build -c release

APP="build/Dell Monitor Console.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/DellMonitorConsole" "$APP/Contents/MacOS/DellMonitorConsole"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# The icon is drawn by the binary itself (`--render-icon`), so the repository holds no binary asset. It must exist
# before signing, because the signature seals the resources. A failure only costs the icon.
ICON_DIR="$(mktemp -d)"
ICONSET="$ICON_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
if "$APP/Contents/MacOS/DellMonitorConsole" --render-icon "$ICON_DIR/base.png" 1024 && [ -f "$ICON_DIR/base.png" ]; then
  for size in 16 32 128 256 512; do
    double=$((size * 2))
    sips -z "$size" "$size" "$ICON_DIR/base.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$double" "$double" "$ICON_DIR/base.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" || printf 'warning: iconutil failed; no app icon.\n' >&2
else
  printf 'warning: could not render the app icon.\n' >&2
fi
rm -rf "$ICON_DIR"

# Ad hoc signature: no certificate is assumed. Each rebuild changes the code identity, so grants tied to it (Keychain,
# privacy) may prompt again after every build.
codesign --force --deep --options runtime --sign - "$APP"

printf '%s\n' "$PWD/$APP"
