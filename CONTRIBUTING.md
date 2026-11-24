# Contributing

Bundle ID: `com.dantanner.dewpoint`

## Architecture

The comfort logic is a pure, platform-agnostic Swift package (`ThermalComfort`)
with no knowledge of watchOS, WeatherKit, or SwiftUI. A second package
(`WeatherData`) turns a location into current conditions, the hourly forecast,
and AQI behind protocols, with App Group caches and the custom-word store. The
apps and widgets compose on top.

The iPhone app is the App Store unit (`com.dantanner.dewpoint`) and embeds the
watch app, which still installs and runs without it. Each device fetches its own
weather; the only thing shared between them is the custom words, through iCloud
key-value storage. Within a device, the App Group carries the app's latest
readings and custom words to its widgets, which also self-fetch on a timeline.

```
Sources/ThermalComfort/    The brain: meteorology, descriptor banding, band layout for display
Sources/WeatherData/       WeatherKit, AirNow and location behind protocols; caches; custom words
AppCore/                   App code shared by the watch and iPhone apps (model, providers, fakes)
App/                       The watch app
Complication/              Watch WidgetKit extension: word, dew point, and AQI complications
Phone/                     The iPhone app: Now, Today, Bands, and Words tabs
PhoneWidget/               iPhone WidgetKit extension: Home and Lock Screen widgets
WidgetShared/              Fetch-and-fallback code shared by both widget extensions
Shared/                    UI bits compiled into every target (AQI colors, palette)
Tests/                     Parity grid, focused unit tests, cache and sync round-trips
```

Screens that explain the bands (the iPhone Bands and Words tabs) get their
ranges by sampling `classify` (`BandLayout`), never by restating thresholds, so
retuning the engine can't leave them stale.

The descriptor logic was validated against a reference implementation by baking a
full integer grid of expected outputs into `Tests/.../Fixtures/parity.csv`. The
parity test replays all ~14.6k cases, so the thresholds can be retuned with
confidence: regenerate the fixture and read the diff.

The full temperature/dew-point → word mapping lives in
[COMFORT_TABLE.md](COMFORT_TABLE.md), kept up to date as we get real-world tuning
feedback. To explore or tweak the bands visually, use the hosted
[comfort band editor](https://dtanner.github.io/the-dew-point/comfort-editor.html).

## Development

Requires Xcode 26+, [`just`](https://github.com/casey/just), and
[`xcodegen`](https://github.com/yonaskolb/XcodeGen). The `.xcodeproj` is generated
from `project.yml` and git-ignored.

```
just test       # run the engine suite (no Xcode/simulator needed)
just build      # build the engine package
just generate   # (re)generate the Xcode project
just build-app  # compile the watch app for the simulator
just build-phone  # compile the iPhone app (with the watch app embedded) for the simulator
just lint       # SwiftLint (strict)
just check      # tests, lint, and all builds — run before committing
just run-sim    # build, install, and launch in the watch simulator
just run-phone-sim 70 64 "" 42  # the iPhone app in the simulator, with fake conditions
just logs       # stream the app's logs from the watch simulator
just deploy     # install on the paired Apple Watch (auto-discovered; or WATCH=<name-or-udid>)
```

Run `just` for the full list.

Building the app targets requires the **watchOS and iOS platform runtimes**
(Xcode ▸ Settings ▸ Components, or `xcodebuild -downloadPlatform watchOS`).
The iPhone build embeds the watch app, so it needs both. The engine package
alone needs neither.

WeatherKit doesn't work in simulators, so pass fake conditions to `run-sim-fake`
or `run-phone-sim` (temperature, dew point, an optional precipitation word, an
optional AQI). The fakes also seed the shared caches, so complications and
widgets placed in the simulator show the same reading, and the iPhone's fake
forecast is a canned day. Custom-word sync needs a signed-in iCloud account,
so check it on real devices.

To light up the air quality complication, request a free key at
[docs.airnowapi.org](https://docs.airnowapi.org) and paste it into
`Config/Secrets.xcconfig` (`just generate` seeds that git-ignored file from
`Config/Secrets.example.xcconfig`). Everything builds and runs without it.

## README screenshots

The app shot in the README is a watchOS simulator capture (iPhone shots are
still to come). The complication
image is rendered from the same descriptor (`just complications`) to mimic a
tinted watch face — the real tint follows the user's watch-face settings.

These images are hosted as assets on the [`assets` release](https://github.com/dtanner/the-dew-point/releases/tag/assets),
not committed to the repo, so screenshots don't bloat git history. To refresh
one, regenerate it locally and run `gh release upload assets <file> --clobber`
— the URLs stay valid.
