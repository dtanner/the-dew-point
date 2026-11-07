import Foundation
import Testing
@testable import WeatherData

/// The complication's fallback reads the cache through an age limit, so an AQI
/// source outage shows as a dash instead of an old number posing as current.
struct AirQualityCacheTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeCache() -> AirQualityCache {
        AirQualityCache(defaults: UserDefaults(suiteName: "AirQualityCacheTests.\(UUID().uuidString)")!)
    }

    @Test func servesReadingWithinMaxAge() {
        let cache = makeCache()
        cache.save(CachedAirQuality(aqi: 51, fetchedAt: now.addingTimeInterval(-60 * 60)))
        #expect(cache.aqi(notOlderThan: 3 * 60 * 60, now: now) == 51)
    }

    @Test func dropsReadingOlderThanMaxAge() {
        let cache = makeCache()
        cache.save(CachedAirQuality(aqi: 51, fetchedAt: now.addingTimeInterval(-4 * 60 * 60)))
        #expect(cache.aqi(notOlderThan: 3 * 60 * 60, now: now) == nil)
    }

    @Test func emptyCacheHasNoReading() {
        #expect(makeCache().aqi(notOlderThan: 3 * 60 * 60, now: now) == nil)
    }
}
