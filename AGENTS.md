# AGENTS.md

Guidance for coding agents working in this repository.

## What this is
A macOS 26 menu bar app (Swift 6, SwiftUI, no dependencies) that sets the brightness of the displays attached to the
Mac. Brightness only. Not affiliated with, endorsed by or supported by Dell.

## Commands
```sh
scripts/bundle.sh              # build and sign build/Dell Monitor Console.app
xcrun swift test               # DDC framing tests
scripts/check-no-network.sh    # must pass
build/Dell\ Monitor\ Console.app/Contents/MacOS/DellMonitorConsole --list   # also: --set <name> <percent>
```
Use `xcrun swift`, not the `swift` on PATH: a swiftly toolchain there fails against the Xcode SDK.

## Rules that must hold
- No network code. Nothing under `Sources/` names a URL or a socket API; the gate enforces it.
- Never run, shell out to, or depend on Dell's DDPM (or any vendor app). Its files are reference material only.
- The only DDC feature sent is brightness (VCP `0x10`). No vendor opcodes, no power, input, or factory commands.
- Private symbols live in `DDC/IOAVBridge.swift` and `Display/Backends.swift` and are resolved with `dlsym`.
- Every DDC request is sent twice, 40 ms apart, before the reply is read: some displays swallow the first command
  after idle, and a single request or a read in between returns only null messages.
- A reply is trusted only after `DDCFrame.parseGetVCP` validates source, length, checksum, opcode, result and the
  echoed VCP code. A display with another client on its channel returns that client's answers too.
- UI state is what the display reported, or visibly pending. Never optimistic and silent.

## Layout
`Sources/DellMonitorConsole/{App,DDC,Display,Store,Persist,UI}`, `Tests/DellMonitorConsoleTests`, `scripts/`.
