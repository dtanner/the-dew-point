import Foundation

/// Source of the current EPA Air Quality Index (0–500, higher is worse). Same
/// actor-isolation shape as `WeatherProviding`, and likewise swapped for fakes in
/// previews and tests.
@MainActor
public protocol AirQualityProviding {
    func currentAQI() async throws -> Int
}

public enum AirQualityError: Error, Equatable {
    /// The response carried no usable observation.
    case noData
    /// AirNow answered with an error message instead of observations — e.g. no
    /// monitor within range (coverage is US-only), a bad key, or a retired endpoint.
    case service(String)
}
