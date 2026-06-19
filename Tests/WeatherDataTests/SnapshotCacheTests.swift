import Foundation
import Testing
@testable import WeatherData

/// The cache is what keeps a complication from going blank when a live fetch fails,
/// so the contract that matters is: what you save is exactly what you load back.
struct SnapshotCacheTests {

    // A throwaway, isolated defaults suite so the test never touches real storage
    // and can't collide with another run.
    private func makeCache() -> (SnapshotCache, UserDefaults) {
        let suite = "SnapshotCacheTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (SnapshotCache(defaults: defaults), defaults)
    }

    private func reading(tempF: Double, dewpointF: Double) -> CachedReading {
        CachedReading(
            snapshot: WeatherSnapshot(temperatureF: tempF, dewpointF: dewpointF, asOf: .now),
            latitude: 37.7749,
            longitude: -122.4194,
            fetchedAt: .now
        )
    }

    @Test func roundTripsASavedReading() {
        let (cache, _) = makeCache()
        let saved = CachedReading(
            snapshot: WeatherSnapshot(
                temperatureF: 71.5,
                dewpointF: 64.2,
                asOf: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            latitude: 37.7749,
            longitude: -122.4194,
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        cache.save(saved)

        #expect(cache.load() == saved)
    }

    @Test func loadReturnsNilWhenEmpty() {
        let (cache, _) = makeCache()
        #expect(cache.load() == nil)
    }

    @Test func saveOverwritesThePreviousReading() {
        let (cache, _) = makeCache()
        cache.save(reading(tempF: 50, dewpointF: 40))

        let latest = reading(tempF: 80, dewpointF: 70)
        cache.save(latest)

        #expect(cache.load() == latest)
    }
}
