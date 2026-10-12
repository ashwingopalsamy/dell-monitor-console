# Metrics

Measured on a MacBook Pro (M4 Pro), macOS 27, with a Dell U2723QE and a Dell U2424HE on USB-C, on 2026-10-11 and
2026-10-12. `scripts/metrics.sh` reproduces the rows marked **measured**. Dell's app (Display and Peripheral Manager
2.3, "DDPM") was launched once, sampled and quit again for the runtime rows; its install size, structure and
history are read from the files it installs and from its own log.

## Footprint

| | Dell Monitor Console | DDPM 2.3 | |
|---|---:|---:|---|
| Installed size | **908 KB** | 42,476 KB | 47× smaller |
| Main executable | **683,072 B** | 16,252,576 B | 24× smaller |
| Files on disk | **4** | 132 | 33× fewer |
| Installer | none, drag the app | 22.4 MB `.pkg`, root install, login helper | |
| Bundled libraries | **0** | 2: a network-KVM framework and Dell's SDK dylib | |
| Languages bundled | 1 | 23 | |
| Source (Swift, non-blank) | **1,402 lines, 15 files** | closed | |

## Runtime, side by side

Both apps freshly launched, left alone, sampled with `top`/`footprint` 40 to 105 s after launch and then over 60 s.

| | Dell Monitor Console | DDPM 2.3 |
|---|---:|---:|
| Memory footprint, idle | **27–29 MB** | 51–52 MB (peak 61 MB) |
| CPU, idle | **0.0 %** | 0.4–0.6 % |
| Energy impact, idle (`top` POWER) | **0.0** | 0.4–0.7 |
| Idle wakeups per minute | **≈ 1** | 24–98 |
| Threads | **5** | 7 |
| Open file descriptors | **45** | 58 |
| Network sockets at rest | **0** | 0 (sampled; see below) |
| Processes | 1 | 1, plus a login helper when auto-launch is on |
| Launch to its first window existing | **≈ 0.26 s** (257, 263, 638 ms) | ≈ 0.3 s (292, 344, 354 ms), window starts hidden |
| CPU time spent in the first ~minute | **0.22 s** (at 48 s) | 1.07 s (at 41 s), 1.39 s (at 105 s) |
| Peak memory while launching | 142 MB, transient (SwiftUI and glass warm-up) | 52–61 MB |

Where DDPM is lighter: its peak while launching. Ours spikes to 142 MB for a moment and settles to 27–29 MB.
Launch time is about the same. The difference is what happens after launch, which is nothing.

| This app only | Value | How |
|---|---:|---|
| Memory footprint, popover open | **34 MB** | `footprint`, fresh instance with `--show` |
| Headless `--list` peak | **8.4 MB** | `/usr/bin/time -l` |
| All displays read | **0.28 s** | `--list` wall time, process start included |
| Slider to confirmed level | **≈ 0.3 s** | `--set` (0.60 s) minus `--list` (0.28 s); write, then read-back |
| Network sockets | **0** | `lsof -i`, and `scripts/check-no-network.sh` |

## Background activity

| | Dell Monitor Console | DDPM 2.3 |
|---|---|---|
| Polls displays while idle | **never**; reads on launch, plug, wake and popover open | re-enumerates every 33 s (median, min 10 s) |
| Monitor connect/disconnect cycles | 0 | 312 connects in 60 minutes |
| Debug log while running | none | 6,947 lines, 668 KiB per hour (its SDK log, level 6) |
| Dock icon | no | yes |
| Login helper | opt-in switch, off by default | installed, auto-launch on |

DDPM's polling figures come from `~/Applications/DDPM/DellMonitorSdk-SUN.log` on this Mac: 6,916 lines over
59.7 minutes. In the two short sampling windows of 2026-10-12 it logged in bursts, none within a 45 s idle window.

## Latency of one DDC/CI exchange

| | Median | Notes |
|---|---:|---|
| DDPM over its USB bridge | 127 ms (p90 132, max 134; n = 383) | from the request line to the reply line in its log |
| This app over the cable | ≈ 140 ms | request pair, 40 ms apart, then the reply 100 ms later |

The wire time is set by the monitor: DDC/CI makes the host wait at least 40 ms and in practice about 100 ms for a
reply. Neither app is meaningfully faster *per exchange*. This app is lighter to *keep*, and does nothing between
your adjustments.

## What each asks of you

| | Dell Monitor Console | DDPM 2.3 |
|---|---|---|
| Privacy permissions | **none** | Accessibility, Automation, Camera, Microphone, Downloads folder |
| Entitlements | none | |
| Network | **none**: no URL and no socket in the sources, gated by a script | 32 URL strings; `dell.com`, `clientperipherals.dell.com`, `downloads.dell.com` |
| Admin rights | none | installer runs as root; its CLI needs admin |
| What it can change on a monitor | **one feature**: brightness (VCP `0x10`) | 45 documented CLI commands: input, power, presets, KVM, firmware, PxP, webcam |
| Which displays | any that answers DDC/CI (verified on two Dell models) | Dell only |

## What is not measured

- Battery life in hours. Idle CPU is 0.0 % and there are no timers, which is the whole argument; the energy figure
  above is `top`'s instantaneous POWER column, not a battery trace.
- DDPM's network traffic. Its sockets were zero when sampled; whether it contacts `dell.com` on a schedule (its
  Live Update) was not observed.
- Other Macs and monitors. The one machine above is the only machine measured, and the figures are single runs of
  60 s windows, not a benchmark suite.

## Where DDPM does more

On purpose, this app does not: change inputs, power, presets, volume or resolution, arrange windows (Easy Arrange),
switch a network KVM, update firmware, or drive a webcam. If you use those, keep DDPM. This is for the one thing most
people open it for.
