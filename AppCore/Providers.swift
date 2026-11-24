import Foundation
import ThermalComfort
import WeatherData

/// Builds the live data sources for the watch and iPhone apps. Kept here rather than
/// in either app's entry point so both apps fetch, cache, and fake conditions the
/// same way.
enum Providers {
    /// How long a WeatherKit or AirNow reading stays fresh in the shared cache. Gating
    /// live fetches on it keeps an app open and a complication's self-fetch from both
    /// hitting the network seconds apart.
    static let ttl: TimeInterval = 15 * 60

    /// The weather source. The foreground default (`location: nil`) uses live
    /// CoreLocation; background callers pass `LastKnownLocationProvider` to avoid
    /// spinning up location streaming in a low-power context.
    @MainActor
    static func weather(location: (any LocationProviding)? = nil) -> any WeatherProviding {
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
        return CachingWeatherProvider(wrapping: WeatherKitProvider(location: location), ttl: ttl)
    }

    /// The AQI counterpart of `weather`, or `nil` when this build carries no AirNow
    /// API key (Config/Secrets.xcconfig empty or absent) — the app then simply shows
    /// no AQI line, and the AQI complication falls back to its cache.
    @MainActor
    static func airQuality(location: (any LocationProviding)? = nil) -> (any AirQualityProviding)? {
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
        return CachingAirQualityProvider(wrapping: AirNowProvider(apiKey: key, location: location), ttl: ttl)
    }

    /// The hourly forecast source, for the iPhone app. With `DEWPOINT_FAKE` set
    /// (DEBUG only) it serves a canned day instead, since WeatherKit doesn't work in
    /// simulators.
    @MainActor
    static func forecast() -> any ForecastProviding {
        #if DEBUG
        if ProcessInfo.processInfo.environment["DEWPOINT_FAKE"] != nil {
            return FakeForecastProvider.sampleDay()
        }
        #endif
        return CachingForecastProvider(wrapping: WeatherKitForecastProvider(), ttl: 30 * 60)
    }
}
