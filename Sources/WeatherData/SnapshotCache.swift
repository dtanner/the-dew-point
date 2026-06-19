import Foundation

/// The App Group shared between the app and the complication extension. They are
/// separate processes, so this is the only storage both can see.
public enum AppGroup {
    public static let identifier = "group.com.dantanner.thedewpoint"

    /// Shared defaults, falling back to `.standard` if the entitlement is missing
    /// (e.g. in a unit-test host) so callers never have to unwrap.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// The last reading the app (or widget) successfully fetched: the conditions plus
/// the coordinate they were read for and the wall-clock time we fetched them.
///
/// The coordinate is the important addition for the complication: a watch widget
/// extension often can't get its own location fix, so the widget reuses this last
/// coordinate to fetch its own fresh weather, and falls back to `snapshot` only if
/// that fetch also fails.
///
/// `fetchedAt` is our own fetch time, distinct from `snapshot.asOf` (WeatherKit's
/// observation time, which lags real time). The TTL gate measures against this so a
/// reading expires a fixed interval after *we* got it, regardless of how stale the
/// underlying observation was.
public struct CachedReading: Codable, Equatable, Sendable {
    public let snapshot: WeatherSnapshot
    public let latitude: Double
    public let longitude: Double
    public let fetchedAt: Date

    public init(snapshot: WeatherSnapshot, latitude: Double, longitude: Double, fetchedAt: Date) {
        self.snapshot = snapshot
        self.latitude = latitude
        self.longitude = longitude
        self.fetchedAt = fetchedAt
    }
}

/// Persists the most recent `CachedReading` so the complication can keep itself
/// current without the app being opened (refetch using the saved coordinate) and
/// never drops to a placeholder when offline (fall back to the saved snapshot).
///
/// Backed by `UserDefaults` rather than a file because the payload is a handful of
/// numbers — too small to justify file plumbing. It lives in the shared App Group
/// so the app and the widget extension, which are separate processes, both see it.
/// The defaults instance is injectable so tests use an isolated suite.
public struct SnapshotCache {
    private static let key = "lastReading"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    public func save(_ reading: CachedReading) {
        guard let data = try? JSONEncoder().encode(reading) else { return }
        defaults.set(data, forKey: Self.key)
    }

    public func load() -> CachedReading? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(CachedReading.self, from: data)
    }
}
