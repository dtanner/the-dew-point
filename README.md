# The Dew Point

A watchOS app (watchOS 26+) that turns the current temperature and dew point into
a single, glanceable word describing how it feels outside — e.g. _Crisp_,
_Muggy_, _Sweltering_. When it's precipitating, the comfort word gives way to
what's falling (_Heavy Rain_, _Scattered Thunderstorms_), taken straight from
WeatherKit's current condition.

Bundle ID: `com.dantanner.dewpoint`

The full temperature/dew-point → word mapping lives in
[COMFORT_TABLE.md](COMFORT_TABLE.md), kept up to date as we get real-world tuning
feedback.

## Screenshots

The app screen and the watch-face word complication, both showing the same sample
condition (_Muggy_):

<p>
  <img src="https://github.com/dtanner/the-dew-point/releases/download/assets/app.png" width="220" alt="The Dew Point app showing Muggy, 70° / dew 64°">
  &nbsp;&nbsp;
  <img src="https://github.com/dtanner/the-dew-point/releases/download/assets/complications.png" width="240" alt="The Word complication showing Muggy">
</p>

The app shot is a watchOS simulator capture. The complication image is rendered
from the same descriptor (`just complications`) to mimic a tinted watch face —
the real tint follows the user's watch-face settings.

These images are hosted as assets on the [`assets` release](https://github.com/dtanner/the-dew-point/releases/tag/assets), not committed to the repo, so screenshots don't bloat git history. To refresh one, regenerate it locally and run `gh release upload assets <file> --clobber` — the URLs above stay valid.

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
Complication/              WidgetKit extension: the word complication
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
