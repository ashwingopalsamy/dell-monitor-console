# Metrics

Two sets of measurements. Version 2.0.0 was measured on 2026-11-02 on a MacBook Pro (M4 Pro), macOS 27.2, with the
built-in display and a Dell U2424HE attached. Version 1.1.2 was measured on 2026-10-11 and 2026-10-12 on the same Mac,
macOS 27, with a Dell U2723QE and a Dell U2424HE on USB-C. A figure marked "measured on 1.1.2" was not measured again;
every other figure for this app is from 2.0.0. `scripts/metrics.sh` reproduces the size, source, memory, thread, socket,
CPU and `--list` figures. Dell's app (Display and Peripheral Manager 2.3, "DDPM") was launched once, sampled and quit
again for the runtime rows during the 1.1.2 measurements, so its figures are unchanged; its install size, structure and
history are read from the files it installs and from its own log.

## Footprint

| | Dell Monitor Console | DDPM 2.3 | |
|---|---:|---:|---|
| Installed size | **1,516 KB** (908 KB on 1.1.2) | 42,476 KB | 28× smaller |
| Main executable | **1,204,544 B** (683,072 B on 1.1.2) | 16,252,576 B | 13× smaller |
| Files on disk | **4** | 132 | 33× fewer |
| Installer | none, drag the app | 22.4 MB `.pkg`, root install, login helper | |
| Bundled libraries | **0** | 2: a network-KVM framework and Dell's SDK dylib | |
| Linked system libraries | 29, all Apple | not measured | |
| Languages bundled | 1 | 23 | |
| Source (Swift, non-blank) | **2,540 lines, 25 files** (1,402 lines, 15 files on 1.1.2) | closed | |

## Runtime, side by side

Both apps freshly launched and left alone. DDPM and this app on 1.1.2 were sampled with `top`/`footprint` 40 to 105 s
after launch and then over 60 s. On 2.0.0 the figures come from `scripts/metrics.sh` against the running app, and the
CPU figure is six 3 s samples.

| | Dell Monitor Console | DDPM 2.3 |
|---|---:|---:|
| Memory footprint, idle | **34 MB** (27–29 MB on 1.1.2) | 51–52 MB (peak 61 MB) |
| CPU, idle | ≈ 0–1 % (six 3 s samples: 0.0, 2.7, 0.0, 0.0, 0.0, 1.1 %; 0.0 % on 1.1.2) | 0.4–0.6 % |
| Energy impact, idle (`top` POWER) | **0.0** (measured on 1.1.2) | 0.4–0.7 |
| Idle wakeups per minute | **≈ 1** (measured on 1.1.2) | 24–98 |
| Threads | **5** | 7 |
| Open file descriptors | **45** (measured on 1.1.2) | 58 |
| Network sockets at rest | **0** | 0 (sampled; see below) |
| Processes | 1 | 1, plus a login helper when auto-launch is on |
| Launch to its first window existing | **≈ 0.26 s** (257, 263, 638 ms; measured on 1.1.2) | ≈ 0.3 s (292, 344, 354 ms), window starts hidden |
| CPU time spent in the first ~minute | **0.22 s** (at 48 s; measured on 1.1.2) | 1.07 s (at 41 s), 1.39 s (at 105 s) |
| Peak memory while launching | 142 MB, transient (SwiftUI and glass warm-up; measured on 1.1.2) | 52–61 MB |

Where DDPM is lighter: its peak while launching. Ours spiked to 142 MB for a moment on 1.1.2 and settles to 34 MB on
2.0.0 (27–29 MB on 1.1.2); the launch peak was not measured again, and why idle memory grew was not investigated. Launch
time is about the same. Idle CPU on 2.0.0 is in the same range as DDPM's, not clearly below it. What differs is what
happens after launch: with an external monitor attached, nothing repeats on a timer.

| This app only | Value | How |
|---|---:|---|
| Memory footprint, popover open | **34 MB** (measured on 1.1.2) | `footprint`, fresh instance with `--show`, on 1.1.2. Idle is also 34 MB on 2.0.0; popover open was not measured again |
| Headless `--list` peak | **8.4 MB** (measured on 1.1.2) | `/usr/bin/time -l` |
| All displays read | **0.30–0.32 s** | `--list` wall time, process start included; the built-in display and one Dell, 0.28 s on 1.1.2 |
| Slider to confirmed level | **≈ 0.3 s** (measured on 1.1.2) | `--set` (0.60 s) minus `--list` (0.28 s), both on 1.1.2; write, then read-back |
| Network sockets | **0** | `lsof -i`, and `scripts/check-no-network.sh` |
| Usage-description strings | **1** | the Automation one, for the Dark Mode fallback |

## Background activity

| | Dell Monitor Console | DDPM 2.3 |
|---|---|---|
| Polls displays while idle | **monitors never**; reads on launch, plug, wake and popover open. The built-in level is re-read every 2 s, only while no external monitor is attached | re-enumerates every 33 s (median, min 10 s) |
| Monitor connect/disconnect cycles | 0 (measured on 1.1.2) | 312 connects in 60 minutes |
| Debug log while running | none | 6,947 lines, 668 KiB per hour (its SDK log, level 6) |
| Dock icon | no | yes |
| Login helper | opt-in switch, off by default | installed, auto-launch on |

The 2 s read: with no external monitor attached, the menu bar icon shows the built-in display's level and the app
re-reads it every 2 s (500 ms tolerance), because the brightness keys and auto-brightness change it without telling the
app. It reads macOS's own brightness, never a monitor, and it is cancelled when an external monitor takes the icon over.
It was not running during the 2.0.0 samples above, which had a Dell attached, so its cost has not been measured. The
monitors themselves are read on launch, wake, display change and popover open (skipped when the last read is under
10 s old), never on a timer.

DDPM's polling figures come from `~/Applications/DDPM/DellMonitorSdk-SUN.log` on this Mac: 6,916 lines over
59.7 minutes. In the two short sampling windows of 2026-10-12 it logged in bursts, none within a 45 s idle window.

## Latency of one DDC/CI exchange

| | Median | Notes |
|---|---:|---|
| DDPM over its USB bridge | 127 ms (p90 132, max 134; n = 383) | from the request line to the reply line in its log |
| This app over the cable | ≈ 140 ms (measured on 1.1.2) | request pair, 40 ms apart, then the reply 100 ms later |

The wire time is set by the monitor: DDC/CI makes the host wait at least 40 ms and in practice about 100 ms for a
reply. Neither app is meaningfully faster *per exchange*. This app is lighter to *keep*, and does nothing between
your adjustments. The DDC/CI code (`Sources/DellMonitorConsole/DDC`) has not changed since 1.1.2, so this figure was
not measured again.

## What each asks of you

| | Dell Monitor Console | DDPM 2.3 |
|---|---|---|
| Privacy permissions | **none** in normal use (Automation, only if the Dark Mode fallback runs) | Accessibility, Automation, Camera, Microphone, Downloads folder |
| Entitlements | one: Automation (`com.apple.security.automation.apple-events`), used only by the Dark Mode fallback | |
| Network | **none**: no network API and no socket in the sources, gated by a script (three About links go to your browser) | 32 URL strings; `dell.com`, `clientperipherals.dell.com`, `downloads.dell.com` |
| Admin rights | none | installer runs as root; its CLI needs admin |
| What it can change on a monitor | **one feature**: brightness (VCP `0x10`). Four in all: True Tone, Dark Mode and Night Shift are set on the Mac, not on the monitor | 45 documented CLI commands: input, power, presets, KVM, firmware, PxP, webcam |
| Which displays | any that answers DDC/CI (verified on two Dell models) | Dell only |

## What is not measured

- Battery life in hours. On 2.0.0 idle CPU is about 0–1 % in six short samples, and with an external monitor attached
  nothing repeats on a timer; the energy figure above is `top`'s instantaneous POWER column from 1.1.2, not a battery
  trace.
- Everything marked "measured on 1.1.2": idle wakeups per minute, energy, launch time and peak memory while launching,
  popover-open memory, open file descriptors, CPU time in the first minute, the headless `--list` peak, slider to
  confirmed level, DDC/CI latency, and monitor connect/disconnect cycles.
- The cost of the 2 s built-in read, and how long a toggle or the Dark Mode fade takes to settle.
- DDPM's network traffic. Its sockets were zero when sampled; whether it contacts `dell.com` on a schedule (its
  Live Update) was not observed.
- Other Macs and monitors. The one machine above is the only machine measured, and the figures are single runs of
  short windows (60 s on 1.1.2, six 3 s CPU samples on 2.0.0), not a benchmark suite.

## Where DDPM does more

On purpose, this app does not: change inputs, power, presets, volume or resolution, arrange windows (Easy Arrange),
switch a network KVM, update firmware, or drive a webcam. If you use those, keep DDPM. This is for the few things most
people open it for.
