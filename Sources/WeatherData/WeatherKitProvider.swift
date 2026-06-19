import Foundation
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
            asOf: current.date
        )
        // Remember the reading and where it was taken so the complication can keep
        // itself current (refetch for this coordinate) without the app being opened.
        cache.save(CachedReading(
            snapshot: snapshot,
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude
        ))
        return snapshot
    }
}
