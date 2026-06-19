import Foundation

/// Serves the last shared reading while it's still fresh, delegating to the
/// wrapped provider (a live WeatherKit fetch) only when the cache is missing or
/// stale.
///
/// The app and the complication are separate processes that each fetch current
/// conditions; before this gate, every app open did one WeatherKit fetch and then
/// `reloadAllTimelines()` made the complication immediately self-fetch a second
/// time for effectively identical data. Both targets now wrap their real provider
/// in this, and both read the same App Group cache, so a fetch by either satisfies
/// the other for the TTL window instead of each hitting WeatherKit.
///
/// `WeatherKitProvider` stays a pure fetch and keeps doing the cache *write* on
/// success, so this decorator only ever needs to read.
@MainActor
public final class CachingWeatherProvider: WeatherProviding {
    private let wrapped: any WeatherProviding
    private let cache: SnapshotCache
    private let ttl: TimeInterval
    private let now: () -> Date

    public init(
        wrapping wrapped: any WeatherProviding,
        cache: SnapshotCache = SnapshotCache(),
        ttl: TimeInterval,
        now: @escaping () -> Date = Date.init
    ) {
        self.wrapped = wrapped
        self.cache = cache
        self.ttl = ttl
        self.now = now
    }

    public func currentSnapshot() async throws -> WeatherSnapshot {
        // `asOf` is WeatherKit's observation time, not our fetch time. For a 15–30
        // min comfort glance that's close enough; if WeatherKit ever returns
        // observations old enough to cause fetch thrashing, add an explicit
        // `fetchedAt` to `CachedReading` and gate on that instead.
        if let cached = cache.load(),
           now().timeIntervalSince(cached.snapshot.asOf) < ttl {
            return cached.snapshot
        }
        return try await wrapped.currentSnapshot()
    }
}
