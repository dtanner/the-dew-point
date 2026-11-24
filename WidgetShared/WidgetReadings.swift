import Foundation
import ThermalComfort
import WeatherData

/// How the widget extensions (watch complications and iPhone widgets) get their
/// readings. Each source self-fetches through the shared TTL cache, locating via
/// the device's own fix or the app's last coordinate — a widget extension often
/// can't get a fix of its own — and falls back to the last cached reading when a
/// live fetch fails, so the glance doesn't go blank between successful fetches.
///
/// Compiled into both extensions (not the apps), so the two renderings fetch,
/// cache and fall back the same way.
@MainActor
enum WidgetReadings {
    /// How often a widget asks to be reloaded. Comfort changes slowly, and WidgetKit
    /// may defer reloads anyway to protect its budget.
    nonisolated static let refreshInterval: TimeInterval = 30 * 60

    /// How old a cached AQI may be and still stand in for a failed fetch. AirNow
    /// updates hourly, so this rides out a couple of missed refreshes without
    /// showing hours-old air.
    nonisolated static let maxAQICacheAge: TimeInterval = 3 * 60 * 60

    /// The current conditions, or `nil` before the app has ever fetched any.
    ///
    /// The TTL gate means a reload the app triggered right after its own fetch is
    /// served from the cache it just wrote, with no second WeatherKit call; a real
    /// fetch re-caches, keeping the fallback current.
    static func snapshot() async -> WeatherSnapshot? {
        let provider = CachingWeatherProvider(
            wrapping: WeatherKitProvider(location: LastKnownLocationProvider()),
            ttl: refreshInterval
        )
        if let snapshot = try? await provider.currentSnapshot() {
            return snapshot
        }
        return SnapshotCache().load()?.snapshot
    }

    /// The current AQI, or `nil` when there's no recent reading (no AirNow key in
    /// this build, or no fetch has succeeded within `maxAQICacheAge`).
    static func aqi() async -> Int? {
        if let key = AirNowProvider.bundledAPIKey {
            let provider = CachingAirQualityProvider(
                wrapping: AirNowProvider(apiKey: key, location: LastKnownLocationProvider()),
                ttl: refreshInterval
            )
            if let aqi = try? await provider.currentAQI() {
                return aqi
            }
        }
        return AirQualityCache().aqi(notOlderThan: maxAQICacheAge)
    }

    /// The coming hours, or `nil` when neither a fetch nor a fresh cache has them —
    /// distinct from an empty forecast, so a widget doesn't claim "no change" when
    /// it simply couldn't load one.
    static func forecast() async -> [ForecastHour]? {
        let provider = CachingForecastProvider(
            wrapping: WeatherKitForecastProvider(location: LastKnownLocationProvider()),
            ttl: refreshInterval
        )
        return try? await provider.hourlyForecast()
    }

    /// The word to show for `snapshot`, resolved as the apps resolve it:
    /// precipitation, then the user's word for the band, then the engine default.
    nonisolated static func descriptor(for snapshot: WeatherSnapshot) -> ComfortDescriptor {
        snapshot.precipitation
            ?? CustomizationStore().resolvedDescriptor(forTempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
    }
}
