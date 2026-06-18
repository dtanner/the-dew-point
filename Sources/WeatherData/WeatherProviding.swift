import Foundation

/// Current outdoor conditions reduced to exactly what the comfort engine needs:
/// temperature and dew point, both in °F. Carries the observation time so the UI
/// can show staleness.
public struct WeatherSnapshot: Equatable, Sendable {
    public let temperatureF: Double
    public let dewpointF: Double
    public let asOf: Date

    public init(temperatureF: Double, dewpointF: Double, asOf: Date) {
        self.temperatureF = temperatureF
        self.dewpointF = dewpointF
        self.asOf = asOf
    }
}

/// Source of current conditions. Main-actor isolated so concrete implementations
/// (which touch CoreLocation / WeatherKit) and the view model that consumes them
/// share one actor — no cross-actor `Sendable` gymnastics for a single-screen
/// app. Swap in a fake conforming type for previews and tests.
@MainActor
public protocol WeatherProviding {
    func currentSnapshot() async throws -> WeatherSnapshot
}
