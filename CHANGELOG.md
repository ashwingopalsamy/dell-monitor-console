# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [SemVer](https://semver.org).

## [Unreleased]

## [2.0.0] - 2026-11-02

Dell Monitor Console is no longer brightness and nothing else. It is now one Liquid Glass panel for every display on
your Mac: a slider per display, then Dark Mode, Night Shift and True Tone as three round toggles, then a way into
System Settings > Displays, so the macOS Display panel can stay closed. Dark Mode now fades across the screen as it
does in System Settings. The app still asks for no permission in normal use; macOS asks for Automation only if the Dark
Mode fallback ever runs. With no external monitor, the menu bar icon shows the built-in display's level, and re-reads
it every 2 seconds.

### Added
- Dark Mode, Night Shift and True Tone toggles under the display sliders. Only the modes this Mac has appear: True Tone
  is hidden when unsupported, Night Shift when CoreBrightness is missing, Dark Mode is always shown.
- A toggle shows pending until the system's own read-back confirms the change. If it never does, the row says "Did not
  change" and shows what the system reported.
- State text is worded as macOS words it: "On Until Sunrise", "Off Until Sunset", a custom schedule's time, and "Until
  Tomorrow" after a manual change inside a schedule (held for the session only). The text keeps its wording and line
  count while a change settles.
- Dark Mode switches under a WindowServer cross-fade (SkyLight), as System Settings' own switch does.
- If the SkyLight call does not take effect within about 300 ms, the app asks System Events instead. macOS asks for
  Automation once, and only then. This adds one usage description (`NSAppleEventsUsageDescription`) and one
  entitlement (`com.apple.security.automation.apple-events`).
- A "Display Settings…" row at the bottom of the panel opens System Settings > Displays and closes the panel.

### Changed
- The popover is a macOS 26 Liquid Glass panel. The header buttons use the system's glass button style, the display
  icon is a glass circle, and each toggle circle carries a glass sheen that responds to the pointer. The panel is made
  key while shown, because glass draws its flat, inactive look in a window that is not key.
- The toggles are drawn like the macOS Display panel: Dark Mode white, Night Shift orange, True Tone blue, with the
  same glyphs and type. The two colours run richer than the system's, because the glass lightens them.
- With no external monitor, the menu bar icon lights its rays to the built-in display's level (the centre dot stays
  off), a scroll over it changes the built-in panel, and the level is re-read every 2 seconds, because the brightness
  keys and auto-brightness change it behind the app's back. That read is macOS's own brightness and never touches a
  monitor. With an external monitor attached the icon follows it, as in 1.1.2. Monitors are still read only on launch,
  wake, display change and popover open (and after 10 seconds stale), never polled.
- Private interfaces are now four, all resolved at runtime: IOAVService, DisplayServices, CoreBrightness (Night Shift,
  True Tone) and SkyLight (Dark Mode and its transition). If one disappears the matching feature hides or falls back;
  Dark Mode falls back to System Events.
- Heavier: 1,516 KB installed (was 908 KB), 34 MB of memory when idle (was 27–29 MB). See [docs/METRICS.md](docs/METRICS.md).

## [1.1.2] - 2026-10-12

### Changed
- The menu bar glyph shows the external monitor's brightness only, never the built-in panel's, and a scroll over it
  changes that same monitor. With no external monitor the centre dot is gone.

## [1.1.1] - 2026-10-12

### Changed
- The menu bar item is only as wide as its glyph, and the glyph is the app icon's dial: eleven rays round a centre dot.
- The lit rays follow the brightness of the display you used last. The centre dot is there while a display is
  detected, and gone when none is.

## [1.1.0] - 2026-10-12

### Changed
- The popover follows Control Center: each display is a section with its name, how it is controlled, the level, and a
  slider with the system accent colour and a sun at each end.
- Refresh, settings and quit are round buttons in the header. Open at login, FAQ and About moved to a settings screen
  inside the popover.

### Added
- FAQ and About screens in the popover, and `--show settings|faq|about` to open one.

## [1.0.0] - 2026-10-12

### Added
- Menu bar popover with a brightness slider per display.
- DDC/CI brightness over the cable, with paired requests for monitors that swallow the first command.
- Software dimming fallback for displays that do not answer DDC/CI.
- Built-in display brightness via macOS.
- Scroll over the icon to change brightness.
- Open at login.
- `--list` and `--set` command-line options.
- No network code and no permissions. The app icon is drawn in code.
