import Foundation
import ThermalComfort
import WeatherKit

/// Fetches current conditions from Apple's WeatherKit for the device location.
///
/// Requires the `com.apple.developer.weatherkit` entitlement on the host app and
/// a location-usage description. WeatherKit also requires visible attribution in
/// the UI (handled by the app's view layer).
@MainActor
public final class WeatherKitProvider: WeatherProviding {
    private let location: any LocationProviding
    private let cache: SnapshotCache
    private let service = WeatherService.shared

    // Defaulted to nil rather than `CoreLocationProvider()` because default
    // argument values are evaluated in a non-isolated context, which can't
    // construct a @MainActor type. Building it inside the (isolated) init is fine.
    public init(location: (any LocationProviding)? = nil, cache: SnapshotCache = SnapshotCache()) {
        self.location = location ?? CoreLocationProvider()
        self.cache = cache
    }

    public func currentSnapshot() async throws -> WeatherSnapshot {
        let place = try await location.currentLocation()
        let current = try await service.weather(for: place, including: .current)
        let snapshot = WeatherSnapshot(
            temperatureF: current.temperature.converted(to: .fahrenheit).value,
            dewpointF: current.dewPoint.converted(to: .fahrenheit).value,
            precipitation: Self.precipitationDescriptor(for: current),
            asOf: current.date
        )
        // Remember the reading, where it was taken, and when we fetched it so the
        // complication can keep itself current (refetch for this coordinate) without
        // the app being opened, and so the TTL gate can age the entry from our fetch
        // time rather than WeatherKit's (older) observation time.
        cache.save(CachedReading(
            snapshot: snapshot,
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            fetchedAt: Date()
        ))
        return snapshot
    }

    /// A precipitation word for the current conditions, or `nil` when nothing is
    /// falling (the UI then shows the comfort word). The word comes straight from
    /// WeatherKit — `condition.description` is the accurate, localized name ("Heavy
    /// Rain", "Scattered Thunderstorms"), so there's no hand-maintained vocabulary
    /// to keep in sync as Apple evolves the condition list.
    private static func precipitationDescriptor(for current: CurrentWeather) -> ComfortDescriptor? {
        guard isPrecipitation(current.condition) else { return nil }
        return ComfortDescriptor(word: current.condition.description)
    }

    /// Whether a condition counts as active precipitation (or a precipitating
    /// storm system) — which is what gates the override on/off. Everything else
    /// (clear, cloudy, fog, haze, wind, …) falls through to `false` and shows the
    /// comfort word instead.
    private static func isPrecipitation(_ condition: WeatherCondition) -> Bool {
        switch condition {
        case .drizzle, .rain, .heavyRain, .sunShowers,
             .flurries, .snow, .heavySnow, .blizzard, .blowingSnow, .sunFlurries,
             .freezingDrizzle, .freezingRain, .sleet, .wintryMix, .hail,
             .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms,
             .strongStorms, .tropicalStorm, .hurricane:
            return true
        default:
            return false
        }
    }
}
