# Security

## Report a vulnerability

Use [private vulnerability reporting](https://github.com/ashwingopalsamy/dell-monitor-console/security/advisories/new).
Please do not open a public issue. Expect a reply within a week.

## Scope

The app sends only the brightness DDC/CI feature (VCP 0x10) to your displays, and has no network code. On the Mac it also switches True Tone, Dark Mode and Night Shift, through CoreBrightness and SkyLight, with System Events as the Dark Mode fallback. It stores a few preferences in UserDefaults and nothing sensitive.

Reports of network access, of any monitor setting written other than brightness, or of a permission prompt in normal use, are in scope.

## Supported versions

The latest release.
