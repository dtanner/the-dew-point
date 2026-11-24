# iPhone app — work plan

Working list for turning the watch-only app into a watch + iPhone app. Mockups:
https://claude.ai/artifact/LRc81DvRPGN6kC2MNHqKG4 (private). Work happens on the
`ios-app` branch; each numbered step should land as its own commit with
`just check` green. Tick items off as they're done and delete this file when the
list is empty.

## Done

- [x] **0. iPhone target.** `TheDewPointPhone` replaces the stub container (same
  bundle ID, embeds the watch app). Watch plist: `WKCompanionAppBundleIdentifier`
  + `WKRunsIndependentlyOfCompanionApp`. Shared app code in `AppCore/`. Now screen
  in `Phone/NowView.swift`. `just build-phone`, `just run-phone-sim`.
- [x] **1. Custom words sync through iCloud key-value storage.**
  `CustomizationStore(cloud:)` / `.synced`; `ConditionsModel.syncCustomizations()`
  runs from each app's root view. First contact merges (cloud wins per band), later
  syncs replace so deletes propagate, and an empty device never pushes. Tests in
  `CustomizationSyncTests`. **Still to verify on devices** (simulators need a
  signed-in iCloud account): edit on phone → watch picks it up, and the reverse.
- [x] **2. Hourly forecast.** `ForecastProviding`, `WeatherKitForecastProvider`,
  `CachingForecastProvider` (App Group, 30 min) and `wordChanges(in:comfortWord:)`
  in `Sources/WeatherData/Forecast.swift`; tests in `ForecastTests`. With
  `DEWPOINT_FAKE` set, `Providers.forecast()` serves `FakeForecastProvider.sampleDay()`.
- [x] **3. Tabs, "Coming up" card, Today tab.** `Phone/RootView.swift` owns the
  refresh/sync tasks; `Phone/TodayView.swift` has the Swift Charts chart and the
  change list. **Still to eyeball:** the Today tab in the simulator.

## To do

- [ ] **4. Bands tab ("Why this word").**
  - Derive display data from `classify` by sampling, not by restating the
    thresholds, so it can't drift from the engine: word segments across dew
    point at the current temperature, and the ordered words per temperature
    band. Lives in `ThermalComfort`, tested.
  - Tapping a segment opens the word editor for that band.

- [ ] **5. Words tab.**
  - Customizations are per *band*, not per word (Muggy appears in four bands),
    so list saved customizations with their band context ("Muggy, 65–74°") and
    allow edit/delete. The mockup's per-word list needs adjusting to this.

- [ ] **6. iPhone widgets.**
  - iOS widget extension: small, medium, Lock Screen circular/rectangular/inline.
  - Reuse the complication's timeline provider where possible (move shared
    pieces next to `Shared/`), with the `AQICategory` colors.

- [ ] **7. Release readiness.**
  - Enable WeatherKit and iCloud (key-value) on the `com.dantanner.dewpoint`
    App ID if automatic signing doesn't.
  - TestFlight build: check that the watch app still installs standalone and
    updates over the existing watch-only version.
  - README / CONTRIBUTING: describe the iPhone app; App Store screenshots.
