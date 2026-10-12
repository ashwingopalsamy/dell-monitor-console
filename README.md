# Dell Monitor Console

A menu bar console for the brightness of the displays on your Mac. One popover, one slider per display,
nothing else. It talks to your monitors over the cable and to nobody else.

## by the numbers

Measured on an M4 Pro Mac with a Dell U2723QE and U2424HE. Method, raw figures and what was not measured:
[docs/METRICS.md](docs/METRICS.md).

| | Dell Monitor Console | Dell's own app (DDPM 2.3) |
|---|---:|---:|
| Installed size | **908 KB** | 42,476 KB |
| Files | **4** | 132 |
| Memory, idle | **27–29 MB** | 51–52 MB |
| CPU, idle | **0.0 %** | 0.4–0.6 % |
| Idle wakeups per minute | **≈ 1** | 24–98 |
| Polls your monitors in the background | **never** | every ~33 s |
| Privacy permissions | **0** | 5 |
| Network | **none** | `dell.com` hosts |
| Launch to its first window | ≈ 0.26 s | ≈ 0.3 s |
| All displays read | **0.28 s** | n/a |
| Features | **1: brightness** | 45 documented commands |

A lite app for the one thing you do most. If you need input switching, KVM, presets or firmware, keep Dell's app.

## what you get

| | |
|---|---|
| **One list** | every display macOS is driving, the built-in one included, each with its own slider |
| **Scroll the icon** | scrolling over the menu bar icon nudges the display you used last, and shows the level in place |
| **Honest state** | a level is shown as set only once the display has reported it; failures are a symbol on the row |
| **No network** | no URL, no socket, no updater. `scripts/check-no-network.sh` fails the build if one appears |
| **Small** | a status item and a popover. No windows, no dock icon |

## how each display is controlled

| Shown as | Meaning |
|---|---|
| no glyph | real backlight control: DDC/CI over the display's cable (external), or macOS (built-in) |
| half-filled circle | **software dimming**: the display did not answer DDC/CI, so the picture is dimmed through its gamma table. It lowers the picture, not the backlight, and lasts while the app runs |
| question mark | the write went through but the display did not confirm the level |
| warning triangle | the display did not accept the change |

Which transport a display uses is decided by a real read each time the displays are enumerated (launch, plug, wake,
popover open), so a monitor that starts answering DDC/CI is picked up without a restart.

Some monitors (the Dell U2723QE is one) swallow the first DDC/CI command after sitting idle and answer only the
second, so every request is sent twice, 40 ms apart, before the reply is read. A single request on those displays
only ever gets a null message, which looks exactly like "DDC/CI is off". The app validates every reply (source,
length, checksum, opcode, echoed feature) and reads a level back after each write before it shows it as set.

## build

```sh
scripts/bundle.sh                       # builds and signs "build/Dell Monitor Console.app"
open "build/Dell Monitor Console.app"
BIN="build/Dell Monitor Console.app/Contents/MacOS/DellMonitorConsole"
"$BIN" --list                    # each display, how it is controlled, its level
"$BIN" --set U2723QE 60          # set the first display whose name matches, print the result
```

Move the app to `/Applications` before turning on **Open at login**. Requires macOS 26 and Apple silicon.
The app is ad hoc signed, so macOS asks once: right-click, Open.

DDC/CI on Apple silicon uses private IOKit entry points (`IOAVService*`) and brightness on the built-in display uses
the private DisplayServices framework. Both are loaded at runtime in one place; if a future macOS removes them the
app keeps running on software dimming.

---

<sub>Not affiliated with, endorsed by or supported by Dell. The name belongs to its owner.
Source-available under [PolyForm Noncommercial 1.0.0](LICENSE): free for noncommercial use. [Notice](NOTICE.md) · [Metrics](docs/METRICS.md) · [Changelog](CHANGELOG.md)</sub>
