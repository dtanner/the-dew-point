import Foundation
import Testing
@testable import WeatherData

/// Same contract as `CachingWeatherProviderTests`, for the AQI gate: a fresh
/// cache is served without calling through, and a missing or stale cache
/// delegates to the wrapped provider.
@MainActor
struct CachingAirQualityProviderTests {

    private final class SpyProvider: AirQualityProviding {
        private(set) var callCount = 0
        let aqi: Int

        init(aqi: Int) {
            self.aqi = aqi
        }

        func currentAQI() async throws -> Int {
            callCount += 1
            return aqi
        }
    }

    private func makeCache() -> AirQualityCache {
        AirQualityCache(defaults: UserDefaults(suiteName: "CachingAirQualityProviderTests.\(UUID().uuidString)")!)
    }

    @Test func servesFreshCacheWithoutFetching() async throws {
        let cache = makeCache()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        cache.save(CachedAirQuality(aqi: 42, fetchedAt: now.addingTimeInterval(-5 * 60)))

        let wrapped = SpyProvider(aqi: 99)
        let provider = CachingAirQualityProvider(
            wrapping: wrapped, cache: cache, ttl: 15 * 60, now: { now }
        )

        #expect(try await provider.currentAQI() == 42)
        #expect(wrapped.callCount == 0)
    }

    @Test func fetchesWhenCacheIsStale() async throws {
        let cache = makeCache()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        cache.save(CachedAirQuality(aqi: 42, fetchedAt: now.addingTimeInterval(-20 * 60)))

        let wrapped = SpyProvider(aqi: 99)
        let provider = CachingAirQualityProvider(
            wrapping: wrapped, cache: cache, ttl: 15 * 60, now: { now }
        )

        #expect(try await provider.currentAQI() == 99)
        #expect(wrapped.callCount == 1)
    }

    @Test func fetchesWhenCacheIsEmpty() async throws {
        let cache = makeCache()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let wrapped = SpyProvider(aqi: 99)
        let provider = CachingAirQualityProvider(
            wrapping: wrapped, cache: cache, ttl: 15 * 60, now: { now }
        )

        #expect(try await provider.currentAQI() == 99)
        #expect(wrapped.callCount == 1)
    }
}
