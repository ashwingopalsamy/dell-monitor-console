# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [SemVer](https://semver.org).

## [Unreleased]

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
