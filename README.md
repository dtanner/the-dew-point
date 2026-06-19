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
with no knowledge of watchOS, WeatherKit, or SwiftUI. A second package
(`WeatherData`) turns a location into current conditions via WeatherKit behind a
protocol. The watch app and the watch-face complication compose on top — the
complication reuses both packages unchanged and fetches on its own timeline.

```
Sources/ThermalComfort/    The brain: meteorology + descriptor banding
Sources/WeatherData/       WeatherKit + location behind a protocol; offline cache
App/                       The watch app (current conditions screen)
Complication/              WidgetKit extension: Word + Icon complications
Tests/                     Parity grid, focused unit tests, cache round-trip
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
- **M2 (done):** standalone watch app — current conditions via WeatherKit +
  location. Deployed to device.
- **M3 (done):** watch-face complications, working on-device. Two fixed kinds —
  _The Dew Point — Word_ and _The Dew Point — Icon_ — so each Modular slot is set
  just by choosing which to place (the most reliable path in the iPhone Watch app).
  The icon uses SF Symbols, since emoji render poorly when tinted. A widget
  extension can't reliably get its own location, so each reading is shared with its
  coordinate through an App Group; the complication then self-fetches fresh weather
  for that coordinate on its own ~30-min timeline (no app-open needed), falling back
  to the last cached reading when offline. The extension ships embedded in the app
  (no extra deploy step). Each word now maps to a distinct SF Symbol (enforced by a
  test). Remaining: confirm on-device that WeatherKit refreshes run inside the
  extension, and eyeball the tinted symbols.
- **M4:** real-world "felt right/off" tuning loop.
