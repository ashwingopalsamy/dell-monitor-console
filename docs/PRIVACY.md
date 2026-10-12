# Privacy

Dell Monitor Console talks to your displays over their cable and to nothing else.

## What it does not have

- **No network.** No network API and no socket anywhere in the sources. `scripts/check-no-network.sh` fails if one
  appears under `Sources/`. The only URL literals are the three links on the About screen, marked `// allow-url`;
  the app hands them to your browser and opens no connection itself.
- **No permissions.** It declares no privacy usage descriptions and no entitlements. Scrolling over its menu bar icon
  is received on its own status item, so there is no Accessibility request.
- **No telemetry, no analytics, no crash reporting, no updater.**
- **No dependencies.** Swift and Apple frameworks only.

## What it keeps

Two things in the app's preferences (`apps.ashwingopalsamy.dellmonitorconsole`): which display you used last, so a scroll over
the menu bar icon nudges that one, and the level of each software-dimmed display, so the dim is applied again after a
relaunch. Nothing else is written, and neither value is sensitive.

## What it touches

It reads and sets one feature on a display, brightness (VCP `0x10`). It sends no power, input, preset or vendor
commands. For software dimming it sets the display's gamma table, which macOS restores when the app quits. The
DDC/CI path (`IOAVService`, in IOKit) and the built-in path (`DisplayServices`) are private interfaces, resolved at
runtime in two files.

## Check it yourself

```sh
# every network socket the app has open: expect no output
lsof -nP -a -p "$(pgrep -f 'Dell Monitor Console.app/Contents/MacOS/DellMonitorConsole$' | head -1)" -i

# the gate that fails on any network API or URL literal in Sources/
scripts/check-no-network.sh

# privacy usage descriptions in the app: expect 0 (use /Applications/Dell Monitor Console.app when installed)
plutil -p "build/Dell Monitor Console.app/Contents/Info.plist" | grep -c UsageDescription

# the two values it keeps
defaults read apps.ashwingopalsamy.dellmonitorconsole
```
