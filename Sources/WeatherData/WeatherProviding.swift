import Foundation
import ThermalComfort

/// Current outdoor conditions reduced to what the comfort engine and UI need:
/// temperature and dew point (both °F), plus a precipitation word when something's
/// falling. Carries the observation time so the UI can show staleness.
public struct WeatherSnapshot: Equatable, Sendable, Codable {
    public let temperatureF: Double
    public let dewpointF: Double
    /// The word to show when it's precipitating, sourced from the weather provider
    /// (the upstream condition's own localized name). `nil` when nothing's falling,
    /// in which case the UI shows the comfort word from `describe`. Optional so
    /// cache entries written before this field still decode (a missing key reads
    /// as `nil`).
    public let precipitation: ComfortDescriptor?
    public let asOf: Date

    public init(temperatureF: Double, dewpointF: Double, precipitation: ComfortDescriptor? = nil, asOf: Date) {
        self.temperatureF = temperatureF
        self.dewpointF = dewpointF
        self.precipitation = precipitation
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
