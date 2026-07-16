import Foundation

/// Serves the last shared AQI while it's still fresh, delegating to the wrapped
/// provider (a live AirNow fetch) only when the cache is missing or stale — the
/// same double-fetch gate as `CachingWeatherProvider`, for the same reason: the
/// app and the AQI complication are separate processes that would otherwise each
/// hit AirNow seconds apart. `AirNowProvider` does the cache write on success, so
/// this decorator only reads.
@MainActor
public final class CachingAirQualityProvider: AirQualityProviding {
    private let wrapped: any AirQualityProviding
    private let cache: AirQualityCache
    private let ttl: TimeInterval
    private let now: () -> Date

    public init(
        wrapping wrapped: any AirQualityProviding,
        cache: AirQualityCache = AirQualityCache(),
        ttl: TimeInterval,
        now: @escaping () -> Date = Date.init
    ) {
        self.wrapped = wrapped
        self.cache = cache
        self.ttl = ttl
        self.now = now
    }

    public func currentAQI() async throws -> Int {
        if let cached = cache.load(),
           now().timeIntervalSince(cached.fetchedAt) < ttl {
            return cached.aqi
        }
        return try await wrapped.currentAQI()
    }
}
