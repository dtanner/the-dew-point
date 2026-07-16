import Foundation

/// The last AQI the app (or widget) successfully fetched, and the wall-clock time
/// we fetched it (the TTL gate ages from this). Unlike `CachedReading` there's no
/// coordinate here: the complication already gets its location fallback from the
/// weather reading's coordinate via `LastKnownLocationProvider`.
public struct CachedAirQuality: Codable, Equatable, Sendable {
    public let aqi: Int
    public let fetchedAt: Date

    public init(aqi: Int, fetchedAt: Date) {
        self.aqi = aqi
        self.fetchedAt = fetchedAt
    }
}

/// Persists the most recent AQI reading, mirroring `SnapshotCache`: it lives in
/// the shared App Group so the AQI complication (a separate process) can serve a
/// fetch by either process while fresh and fall back to the last good value when
/// a live fetch fails.
public struct AirQualityCache {
    private static let key = "lastAirQuality"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    public func save(_ reading: CachedAirQuality) {
        guard let data = try? JSONEncoder().encode(reading) else { return }
        defaults.set(data, forKey: Self.key)
    }

    public func load() -> CachedAirQuality? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(CachedAirQuality.self, from: data)
    }
}
