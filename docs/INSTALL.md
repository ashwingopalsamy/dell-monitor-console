# Install

<!-- unreleased -->
Dell Monitor Console is not released yet: there is no DMG, no Homebrew cask and no GitHub release. Build it from
source; there are no dependencies to fetch.
<!-- /unreleased -->
<!-- released
Install it with Homebrew, download the DMG, or build it from source. There are no dependencies.

## Homebrew

```sh
brew install --cask ashwingopalsamy/tap/dell-monitor-console
```

## DMG

Download [Dell-Monitor-Console-{{version}}.dmg](https://github.com/ashwingopalsamy/dell-monitor-console/releases/download/v{{version}}/Dell-Monitor-Console-{{version}}.dmg)
from the [latest release](https://github.com/ashwingopalsamy/dell-monitor-console/releases/latest), drag the app to
Applications, and verify it first:

```sh
shasum -a 256 -c Dell-Monitor-Console-*.dmg.sha256
gh attestation verify Dell-Monitor-Console-*.dmg -R ashwingopalsamy/dell-monitor-console
```

The app is not notarised, so macOS asks once: right-click the app and choose Open, or run
`xattr -dr com.apple.quarantine "/Applications/Dell Monitor Console.app"`.
/released -->

## From source

```sh
git clone https://github.com/ashwingopalsamy/dell-monitor-console
cd dell-monitor-console
scripts/bundle.sh
open "build/Dell Monitor Console.app"
```

Needs macOS 26, Apple silicon, and Xcode 26 or its Command Line Tools. The app is ad hoc signed, so macOS asks once:
right-click the app and choose Open. Move it to `/Applications` before turning on **Open at login**.

## Command line

The same binary is a CLI. Both commands read the displays and exit.

```sh
BIN="build/Dell Monitor Console.app/Contents/MacOS/DellMonitorConsole"
"$BIN" --list              # name, path, level, state: one line per display
"$BIN" --set U2723QE 60    # the first display whose name contains the text
```

`--set` exits non-zero when no display matches or the display did not accept the change.

## Uninstall

Turn off **Open at login** in the popover, quit from it, and delete the app. To clear what it stored, run
`defaults delete apps.ashwingopalsamy.dellmonitorconsole`. A software dim ends when the app quits. A level set over DDC/CI is
the monitor's own setting and stays.

<!-- released
With Homebrew: `brew uninstall --zap --cask dell-monitor-console`.
/released -->
