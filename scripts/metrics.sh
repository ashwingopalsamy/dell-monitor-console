#!/bin/sh
# Prints the numbers quoted in docs/METRICS.md. Run it on the machine you want to measure, with the app built
# (scripts/bundle.sh) and, for the memory rows, running. It never starts, signals or loads Dell's DDPM: the DDPM
# rows are read from files on disk and from DDPM's own log, and its memory is sampled only if it is already running.
set -eu
cd "$(dirname "$0")/.."
APP="build/Dell Monitor Console.app"
BIN="$APP/Contents/MacOS/DellMonitorConsole"
[ -x "$BIN" ] || { echo "build the app first: scripts/bundle.sh" >&2; exit 1; }

row() { printf '%-34s %s\n' "$1" "$2"; }
kb() { du -sk "$1" | awk '{print $1}'; }

echo "== Dell Monitor Console"
row "bundle on disk (KB)" "$(kb "$APP")"
row "executable (bytes)" "$(stat -f %z "$BIN")"
row "files in bundle" "$(find "$APP" -type f | wc -l | tr -d ' ')"
row "linked libraries (all Apple)" "$(otool -L "$BIN" | tail -n +2 | wc -l | tr -d ' ')"
row "swift files / non-blank lines" "$(find Sources -name '*.swift' | wc -l | tr -d ' ') / $(cat $(find Sources -name '*.swift') | grep -cvE '^[[:space:]]*$')"
row "usage-description strings" "$(grep -c UsageDescription "$APP/Contents/Info.plist" || true)"

PID="$(pgrep -f 'Dell Monitor Console.app/Contents/MacOS/DellMonitorConsole$' | head -1 || true)"
if [ -n "$PID" ]; then
  row "memory footprint, running (MB)" "$(footprint -p "$PID" 2>/dev/null | awk '/phys_footprint:/ {print $2, $3}')"
  row "threads" "$(ps -M -p "$PID" | tail -n +2 | wc -l | tr -d ' ')"
  row "network sockets" "$(lsof -nP -a -p "$PID" -i 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
  row "cpu now (%)" "$(top -pid "$PID" -l 2 -s 1 -stats cpu | tail -1 | tr -d ' ')"
else
  echo "(app not running: memory, threads, sockets and cpu skipped)"
fi
for i in 1 2 3; do
  t0=$(python3 -c 'import time; print(time.perf_counter())')
  "$BIN" --list >/dev/null
  t1=$(python3 -c 'import time; print(time.perf_counter())')
  row "--list wall, run $i (s)" "$(python3 -c "print(f'{$t1 - $t0:.2f}')")"
done

D=/Applications/DDPM
if [ -d "$D" ]; then
  echo
  echo "== Dell Display and Peripheral Manager (static; never executed)"
  row "install dir on disk (KB)" "$(kb "$D")"
  row "main binary (bytes)" "$(stat -f %z "$D/DDPM.app/Contents/MacOS/DDPM")"
  row "files installed" "$(find "$D" -type f | wc -l | tr -d ' ')"
  row "languages (.lproj)" "$(find "$D" -name '*.lproj' | wc -l | tr -d ' ')"
  row "https/http strings in binary" "$(strings -a "$D/DDPM.app/Contents/MacOS/DDPM" | grep -ciE 'https?://' || true)"
  row "usage-description strings" "$(plutil -p "$D/DDPM.app/Contents/Info.plist" | grep -c UsageDescription || true)"
  row "shows in the Dock" "$(plutil -extract LSUIElement raw "$D/DDPM.app/Contents/Info.plist" 2>/dev/null | sed 's/false/yes/;s/true/no/')"
  DPID="$(pgrep -f '/Applications/DDPM/DDPM.app/Contents/MacOS/DDPM$' | head -1 || true)"
  if [ -n "$DPID" ]; then
    row "memory footprint, running (MB)" "$(footprint -p "$DPID" 2>/dev/null | awk '/phys_footprint:/ {print $2, $3}')"
    row "threads" "$(ps -M -p "$DPID" | tail -n +2 | wc -l | tr -d ' ')"
    row "open file descriptors" "$(lsof -nP -p "$DPID" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
    row "network sockets" "$(lsof -nP -a -p "$DPID" -i 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
    row "cpu now (%)" "$(top -pid "$DPID" -l 2 -s 1 -stats cpu | tail -1 | tr -d ' ')"
  else
    echo "(DDPM not running: its runtime rows are skipped. Start it yourself and re-run; this script never starts it.)"
  fi
  LOG="$HOME/Applications/DDPM/DellMonitorSdk-SUN.log"
  [ -f "$LOG" ] && row "its SDK log size (bytes)" "$(stat -f %z "$LOG")"
fi
