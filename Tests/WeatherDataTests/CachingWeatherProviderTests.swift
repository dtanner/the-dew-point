import Foundation
import Testing
@testable import WeatherData

/// The decorator's whole job is to gate the live fetch on a TTL, so the contract
/// that matters is: a fresh cache is served without calling through, and a missing
/// or stale cache delegates to the wrapped provider.
@MainActor
struct CachingWeatherProviderTests {

    /// Records whether it was called and returns a snapshot distinct from the cache
    /// so tests can tell which path served the result.
    private final class SpyProvider: WeatherProviding {
        private(set) var callCount = 0
        let snapshot: WeatherSnapshot

        init(snapshot: WeatherSnapshot) {
            self.snapshot = snapshot
        }

        func currentSnapshot() async throws -> WeatherSnapshot {
            callCount += 1
            return snapshot
        }
    }

    private func makeCache() -> (SnapshotCache, UserDefaults) {
        let suite = "CachingWeatherProviderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (SnapshotCache(defaults: defaults), defaults)
    }

    private func cachedReading(asOf: Date, tempF: Double) -> CachedReading {
        CachedReading(
            snapshot: WeatherSnapshot(temperatureF: tempF, dewpointF: 50, asOf: asOf),
            latitude: 37.7749,
            longitude: -122.4194
        )
    }

    @Test func servesFreshCacheWithoutFetching() async throws {
        let (cache, _) = makeCache()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        cache.save(cachedReading(asOf: now.addingTimeInterval(-5 * 60), tempF: 70))

        let wrapped = SpyProvider(
            snapshot: WeatherSnapshot(temperatureF: 99, dewpointF: 99, asOf: now)
        )
        let provider = CachingWeatherProvider(
            wrapping: wrapped, cache: cache, ttl: 15 * 60, now: { now }
        )

        let result = try await provider.currentSnapshot()

        #expect(result.temperatureF == 70)
        #expect(wrapped.callCount == 0)
    }

    @Test func fetchesWhenCacheIsStale() async throws {
        let (cache, _) = makeCache()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        cache.save(cachedReading(asOf: now.addingTimeInterval(-20 * 60), tempF: 70))

        let wrapped = SpyProvider(
            snapshot: WeatherSnapshot(temperatureF: 99, dewpointF: 99, asOf: now)
        )
        let provider = CachingWeatherProvider(
            wrapping: wrapped, cache: cache, ttl: 15 * 60, now: { now }
        )

        let result = try await provider.currentSnapshot()

        #expect(result.temperatureF == 99)
        #expect(wrapped.callCount == 1)
    }

    @Test func fetchesWhenCacheIsEmpty() async throws {
        let (cache, _) = makeCache()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let wrapped = SpyProvider(
            snapshot: WeatherSnapshot(temperatureF: 99, dewpointF: 99, asOf: now)
        )
        let provider = CachingWeatherProvider(
            wrapping: wrapped, cache: cache, ttl: 15 * 60, now: { now }
        )

        let result = try await provider.currentSnapshot()

        #expect(result.temperatureF == 99)
        #expect(wrapped.callCount == 1)
    }
}
