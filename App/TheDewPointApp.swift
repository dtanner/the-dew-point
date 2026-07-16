import SwiftUI
import ThermalComfort
import WatchKit
import WeatherData
import WidgetKit

@main
struct TheDewPointApp: App {
    // watchOS only honors a complication's `.after` reload hint within a limited
    // background budget, so left alone the watch face only refreshes when the app
    // is opened. The delegate below schedules our own background app refresh to
    // fetch fresh weather (in the app process, which has full location access and a
    // real execution window — unlike the time-boxed widget extension) and then
    // reload the complications.
    @WKApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            // The live app reads real conditions from WeatherKit (and AQI from
            // AirNow). Views are driven by the providing protocols, so
            // previews/tests inject fakes.
            ContentView(model: ConditionsModel(
                provider: Self.makeProvider(),
                airQuality: Self.makeAQIProvider()
            ))
        }
    }

    /// How far out to ask the system to wake us. watchOS throttles background
    /// refresh to roughly hourly for an app with an active complication, so this is
    /// a lower bound the system rounds up — it won't make us fire more often.
    fileprivate static let refreshInterval: TimeInterval = 30 * 60

    @MainActor
    private static func makeProvider(location: (any LocationProviding)? = nil) -> any WeatherProviding {
        #if DEBUG
        // Screenshot/UI hook: set DEWPOINT_FAKE="<tempF>,<dewpointF>[,<precip word>]"
        // to bypass WeatherKit with fixed conditions (`just run-sim-fake` sets it).
        // A third token forces a precipitation word (e.g. "Snow", "Heavy Rain").
        // Never in release builds.
        if let env = ProcessInfo.processInfo.environment["DEWPOINT_FAKE"] {
            let parts = env.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, let tempF = Double(parts[0]), let dewpointF = Double(parts[1]) {
                let precipitation = parts.count >= 3 ? ComfortDescriptor(word: parts[2]) : nil
                let snapshot = WeatherSnapshot(temperatureF: tempF, dewpointF: dewpointF, precipitation: precipitation, asOf: .now)
                // The complication runs in its own process and can't see this env
                // var, so seed the shared cache too: its provider then serves these
                // conditions (fresh within TTL) instead of hitting WeatherKit —
                // which is how the complication is verified in the simulator, where
                // WeatherKit doesn't work. The zero coordinate is a placeholder;
                // it's only read for a live fetch, which the fake exists to avoid.
                SnapshotCache().save(CachedReading(snapshot: snapshot, latitude: 0, longitude: 0, fetchedAt: .now))
                return FakeWeatherProvider(snapshot: snapshot)
            }
        }
        #endif
        // Gate live fetches behind a TTL reading the shared cache, so an app open
        // and the complication's self-fetch don't both hit WeatherKit seconds apart.
        // The foreground default (`location: nil`) uses live CoreLocation; background
        // callers pass `LastKnownLocationProvider` to avoid spinning up location
        // streaming in a low-power context.
        return CachingWeatherProvider(wrapping: WeatherKitProvider(location: location), ttl: 15 * 60)
    }

    /// The AQI counterpart of `makeProvider`, or `nil` when this build carries no
    /// AirNow API key (Config/Secrets.xcconfig empty or absent) — the app then
    /// simply shows no AQI line, and the AQI complication falls back to its cache.
    @MainActor
    private static func makeAQIProvider(location: (any LocationProviding)? = nil) -> (any AirQualityProviding)? {
        #if DEBUG
        // Screenshot/UI hook alongside DEWPOINT_FAKE: set DEWPOINT_FAKE_AQI=<int>
        // to bypass AirNow (`just run-sim-fake` can set it). Seeds the shared
        // cache for the same reason DEWPOINT_FAKE does: the complication can't
        // see the env var, so it reads these conditions from the cache instead.
        if let env = ProcessInfo.processInfo.environment["DEWPOINT_FAKE_AQI"],
           let aqi = Int(env) {
            AirQualityCache().save(CachedAirQuality(aqi: aqi, fetchedAt: .now))
            return FakeAirQualityProvider(aqi: aqi)
        }
        #endif
        guard let key = AirNowProvider.bundledAPIKey else { return nil }
        return CachingAirQualityProvider(
            wrapping: AirNowProvider(apiKey: key, location: location),
            ttl: 15 * 60
        )
    }

    /// Asks watchOS to wake the app for a background refresh after `refreshInterval`.
    fileprivate static func scheduleBackgroundRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date.now.addingTimeInterval(refreshInterval),
            userInfo: nil
        ) { _ in
            // Best-effort: if scheduling failed there's nothing useful to do here,
            // and the next app launch re-seeds the chain via the delegate.
        }
    }

    /// Background-refresh work: fetch fresh weather (which writes the shared cache),
    /// push the new reading to the complications, then schedule the next wake-up so
    /// the chain continues without the app being opened.
    @MainActor
    fileprivate static func handleBackgroundRefresh() async {
        defer { scheduleBackgroundRefresh() }
        // Failed fetches (no fix, no network) just leave the caches as-is; the
        // complications keep showing the last good readings until the next wake-up.
        _ = try? await makeProvider(location: LastKnownLocationProvider()).currentSnapshot()
        if let aqiProvider = makeAQIProvider(location: LastKnownLocationProvider()) {
            _ = try? await aqiProvider.currentAQI()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Drives background app refresh. SwiftUI's `App` has no launch/background-task
/// hooks on watchOS, so we attach a `WKApplicationDelegate`: seed the refresh chain
/// at launch, and on each scheduled wake-up do the fetch+reload work, then mark the
/// task complete (required, or watchOS stops granting us background time).
final class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        TheDewPointApp.scheduleBackgroundRefresh()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            guard let refresh = task as? WKApplicationRefreshBackgroundTask else {
                task.setTaskCompletedWithSnapshot(false)
                continue
            }
            Task { @MainActor in
                await TheDewPointApp.handleBackgroundRefresh()
                refresh.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
