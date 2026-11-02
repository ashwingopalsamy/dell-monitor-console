# Privacy

Dell Monitor Console talks to your displays over their cable and to your Mac's own display interfaces. It talks to
nothing else.

## What it does not have

- **No network.** No network API and no socket anywhere in the sources. `scripts/check-no-network.sh` fails if one
  appears under `Sources/`. The only web links are the three on the About screen, marked `// allow-url`; the app hands
  them to your browser and opens no connection itself. The "Display Settings…" row opens a System Settings address
  (`x-apple.systempreferences:`), which macOS handles and which is not a network address.
- **No permissions in normal use.** One usage description (`NSAppleEventsUsageDescription`) and one entitlement
  (`com.apple.security.automation.apple-events`) exist, both for the Dark Mode fallback: if switching Dark Mode through
  SkyLight does not take effect, the app asks System Events instead. macOS asks for Automation only if that fallback
  runs, and then once. Scrolling over the menu bar icon is received on the app's own status item, so there is no
  Accessibility request.
- **No telemetry, no analytics, no crash reporting, no updater.**
- **No dependencies.** Swift and Apple frameworks only.

## What it keeps

Two things in the app's preferences (`apps.ashwingopalsamy.dellmonitorconsole`): which display you used last, so the
menu bar icon follows that monitor and a scroll over it nudges it, and the level of each software-dimmed display, so the
dim is applied again after a relaunch. Nothing else is written, and neither value is sensitive. The one thing it
remembers beyond that, that you changed Night Shift or Dark Mode by hand inside a schedule (it shows as "Until
Tomorrow"), lives in memory for the session and is not written anywhere.

## What it touches

It reads and sets one feature on a display, brightness (VCP `0x10`). It sends no power, input, preset or vendor
commands. For software dimming it sets the display's gamma table, which macOS restores when the app quits. It also
turns True Tone, Dark Mode and Night Shift on or off and reads whether each is on; it changes no Night Shift schedule
or strength. Those go through CoreBrightness (True Tone, Night Shift) and SkyLight (Dark Mode), with System Events as
the Dark Mode fallback. To word the Dark Mode text it reads the system's automatic-appearance setting. The DDC/CI path
(`IOAVService`, in IOKit), the built-in path (`DisplayServices`), CoreBrightness and SkyLight are private interfaces,
resolved at runtime in three files.

It reads your monitors on launch, wake, display change and popover open, and never polls them. With no external
monitor attached, the menu bar icon shows the built-in display's level and the app re-reads it every 2 s, because the
brightness keys and auto-brightness change it behind the app's back. That read goes to macOS's own brightness and
never touches a monitor.

## Check it yourself

```sh
# every network socket the app has open: expect no output
lsof -nP -a -p "$(pgrep -f 'Dell Monitor Console.app/Contents/MacOS/DellMonitorConsole$' | head -1)" -i

# the gate that fails on any network API or URL literal in Sources/
scripts/check-no-network.sh

# privacy usage descriptions in the app: expect 1, the Automation one (use /Applications/Dell Monitor Console.app when installed)
plutil -p "build/Dell Monitor Console.app/Contents/Info.plist" | grep -c UsageDescription

# entitlements: expect one, com.apple.security.automation.apple-events
codesign -d --entitlements - "build/Dell Monitor Console.app"

# the two values it keeps
defaults read apps.ashwingopalsamy.dellmonitorconsole
```
