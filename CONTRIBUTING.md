# Contributing

Small, focused pull requests are easiest to review.

## Build and test

```sh
scripts/bundle.sh             # build and ad hoc sign build/Dell Monitor Console.app
xcrun swift test              # unit tests
scripts/check-no-network.sh   # network check
```

macOS 26 on Apple silicon and Xcode 26 (or its Command Line Tools) are required. There are no dependencies to install.

## Rules that keep the app trustworthy

- The app has no network code. `scripts/check-no-network.sh` fails on any network API or URL literal under `Sources/`, comments included. A line marked `// allow-url` is exempt; justify it in the PR.
- The app reads and writes one DDC/CI feature, brightness (VCP 0x10). Any other feature code can change a monitor's settings, so it needs a discussion first.
- No dependencies. A new package needs a discussion first.

## Commits

[Conventional Commits](https://www.conventionalcommits.org), short:

```
feat(ui): add a slider per display
fix(ddc): pair requests for idle monitors
docs: explain software dimming
```

Subject under 50 characters, imperative, no full stop. Add a body only when the why is not obvious.

## Pull requests

Four lines: what, why, how to check, risk. Link an issue if there is one.
