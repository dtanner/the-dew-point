# The Dew Point

A watchOS app (watchOS 26+) that turns the current temperature and dew point into
a single, glanceable word and icon describing how it feels outside — e.g.
_Crisp_ 🍃, _Muggy_ 😓, _Sweltering_ 🔥.

**Vocabulary:** each condition produces a **word** and an **icon** (two
independent display channels). The icon has two renditions — a color **emoji**
for the app and an SF **symbol** for tinted complications. The terms _word_,
_icon_, _emoji_, and _symbol_ are used consistently throughout the code.

Bundle ID: `com.dantanner.thedewpoint`

## Architecture

The comfort logic is a pure, platform-agnostic Swift package (`ThermalComfort`)
with no knowledge of watchOS, WeatherKit, or SwiftUI. The watch app and the
watch-face complication compose on top of it.

```
Sources/ThermalComfort/   The brain: meteorology + descriptor banding
Tests/ThermalComfortTests/ Parity grid + focused unit tests
```

The descriptor logic was validated against a reference implementation by baking a
full integer grid of expected outputs into `Tests/.../Fixtures/parity.csv`. The
parity test replays all ~14.6k cases, so the thresholds can be retuned with
confidence: regenerate the fixture and read the diff.

## Development

Requires Xcode 26+, [`just`](https://github.com/casey/just), and
[`xcodegen`](https://github.com/yonsson/XcodeGen). The `.xcodeproj` is generated
from `project.yml` and git-ignored.

```
just test       # run the engine suite (no Xcode/simulator needed)
just build      # build the engine package
just generate   # (re)generate the Xcode project
just build-app  # compile the watch app for the simulator
```

Building or running the watch app target requires the **watchOS platform
runtime** to be installed (Xcode ▸ Settings ▸ Components, or
`xcodebuild -downloadPlatform watchOS`). The engine package alone does not.

## Status

- **M1 (done):** comfort engine + parity tests.
- **M2 (in progress):** standalone watch app — current conditions via WeatherKit +
  location. Code compiles for watchOS 26; on-device run pending the platform
  runtime install.
- **M3:** watch-face complications — each slot independently configurable to show
  the word or the icon (e.g. word in one Modular slot, icon in another). Uses SF
  Symbols, since emoji render poorly tinted.
