#!/bin/sh
# Renders the brand images the site and README use from the app's own icon code, so they cannot drift from it.
# Usage: scripts/brand.sh [output-dir]   (default: site/public)
set -eu
cd "$(dirname "$0")/.."
OUT="${1:-site/public}"
BIN="build/Dell Monitor Console.app/Contents/MacOS/DellMonitorConsole"
[ -x "$BIN" ] || { echo "build the app first: scripts/bundle.sh" >&2; exit 1; }
mkdir -p "$OUT/brand"
r() { "$BIN" --render-icon "$1" "$2" "${3:-full}" "${4:-0.75}"; }

r "$OUT/icon-512.png" 512
r "$OUT/icon-192.png" 192
r "$OUT/apple-touch-icon.png" 180
r "$OUT/favicon-32.png" 64
# Layers, so a banner can stack them and move the rays.
r "$OUT/brand/tile.png" 512 tile
r "$OUT/brand/tile-xl.png" 1280 tile
r "$OUT/brand/glyph.png" 512 glyph
r "$OUT/brand/glyph-xl.png" 1280 glyph
echo "brand images -> $OUT"
