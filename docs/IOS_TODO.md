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
  `CustomizationSyncTests`. Verified on devices 2026-11-24 (iPhone 15 Pro +
  Ultra): a word saved on either shows on the other when its app opens. **Still to
  check:** the watch complication picking it up through background refresh without
  opening the watch app.
- [x] **2. Hourly forecast.** `ForecastProviding`, `WeatherKitForecastProvider`,
  `CachingForecastProvider` (App Group, 30 min) and `wordChanges(in:comfortWord:)`
  in `Sources/WeatherData/Forecast.swift`; tests in `ForecastTests`. With
  `DEWPOINT_FAKE` set, `Providers.forecast()` serves `FakeForecastProvider.sampleDay()`.
- [x] **3. Tabs, "Coming up" card, Today tab.** `Phone/RootView.swift` owns the
  refresh/sync tasks; `Phone/TodayView.swift` has the Swift Charts chart and the
  change list. **Still to eyeball:** the Today tab in the simulator.
- [x] **4. Bands tab.** `BandLayout` in `ThermalComfort` samples `classify` for
  the dew-point segments at a temperature and the words per temperature band
  (`BandLayoutTests`); `Phone/BandsView.swift` draws them, and tapping a segment
  opens `CustomWordEditor` for that band. Open question for the spec: the
  80–89°F "Steamy" rule (`hotSteamy`) is unreachable — see
  `everyReachableBandAppearsOnceInItsOwnRow`.
- [x] **5. Words tab.** `Phone/WordsView.swift`: saved custom words (edit,
  swipe to delete), then every band grouped by temperature band, each with its
  range from `BandEntry` (sampled extents plus a reading to save against). The
  band editor sheet and range labels shared with the Bands tab live in
  `Phone/BandEditing.swift`.
- [x] **6. iPhone widgets.** `TheDewPointPhoneWidget` extension (`PhoneWidget/`):
  Comfort Word (small, medium with coming-up changes, Lock Screen rectangular and
  inline) plus Dew Point and Air Quality Lock Screen circles. Fetching lives in
  `WidgetShared/WidgetReadings.swift`, shared with the watch complication;
  `upcomingWordChanges` in WeatherData keeps the widget and the app's card in
  step. Small and medium eyeballed in the simulator. **Still to eyeball:** the
  Lock Screen widgets, and the watch complication on-device after the provider
  refactor.

## To do

- [ ] **7. Release readiness.**
  - Done 2026-11-24: WeatherKit's **App Services** checkbox on the
    `com.dantanner.dewpoint` App ID (automatic signing sets the capability but
    not this; without it every fetch fails with a WeatherKit auth error).
  - Enable WeatherKit and iCloud (key-value) on the `com.dantanner.dewpoint`
    App ID if automatic signing doesn't, and WeatherKit + the App Group on the
    new `com.dantanner.dewpoint.widget` App ID. The ASC API key can't register a
    new App ID: run one archive with plain `-allowProvisioningUpdates` first.
  - TestFlight build: check that the watch app still installs standalone and
    updates over the existing watch-only version.
  - App Store screenshots for the iPhone (README and CONTRIBUTING already
    describe the iPhone app; add iPhone shots to the README's assets release
    too).
