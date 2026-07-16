import Foundation

/// Source of the current EPA Air Quality Index (0–500, higher is worse). Same
/// actor-isolation shape as `WeatherProviding`, and likewise swapped for fakes in
/// previews and tests.
@MainActor
public protocol AirQualityProviding {
    func currentAQI() async throws -> Int
}

public enum AirQualityError: Error, Equatable {
    /// The response carried no usable observation — typically no reporting
    /// station within the search radius (AirNow coverage is US-only).
    case noData
}
