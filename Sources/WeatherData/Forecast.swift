import Foundation
import ThermalComfort
import WeatherKit

/// One forecast hour reduced to what the comfort engine needs — the hourly
/// counterpart of `WeatherSnapshot`.
public struct ForecastHour: Equatable, Sendable, Codable {
    /// Start of the hour.
    public let date: Date
    public let temperatureF: Double
    public let dewpointF: Double
    /// The precipitation word for the hour, or `nil` when nothing's expected to fall.
    public let precipitation: ComfortDescriptor?

    public init(date: Date, temperatureF: Double, dewpointF: Double, precipitation: ComfortDescriptor? = nil) {
        self.date = date
        self.temperatureF = temperatureF
        self.dewpointF = dewpointF
        self.precipitation = precipitation
    }
}

/// Source of the hourly forecast. Separate from `WeatherProviding` so the watch app
/// and complication, which only show current conditions, never fetch it.
@MainActor
public protocol ForecastProviding {
    /// The hours from the current one onward, oldest first.
    func hourlyForecast() async throws -> [ForecastHour]
}

/// Fetches the hourly forecast from WeatherKit for the device location.
@MainActor
public final class WeatherKitForecastProvider: ForecastProviding {
    /// How many hours ahead to keep: through tomorrow morning from any time of day.
    public static let horizon = 24

    private let location: any LocationProviding
    private let now: () -> Date

    // `location` defaults to nil for the same reason as `WeatherKitProvider`: a
    // @MainActor default can't be constructed in a default-argument expression.
    public init(location: (any LocationProviding)? = nil, now: @escaping () -> Date = Date.init) {
        self.location = location ?? CoreLocationProvider()
        self.now = now
    }

    public func hourlyForecast() async throws -> [ForecastHour] {
        let place = try await location.currentLocation()
        let hourly = try await WeatherService.shared.weather(for: place, including: .hourly)
        // WeatherKit's hourly forecast starts at midnight today; keep the current
        // hour onward.
        let currentHourStart = now().addingTimeInterval(-3600)
        return hourly.forecast
            .filter { $0.date > currentHourStart }
            .prefix(Self.horizon)
            .map { hour in
                ForecastHour(
                    date: hour.date,
                    temperatureF: hour.temperature.converted(to: .fahrenheit).value,
                    dewpointF: hour.dewPoint.converted(to: .fahrenheit).value,
                    precipitation: precipitationDescriptor(for: hour.condition)
                )
            }
    }
}

/// Serves the last fetched forecast while it's fresh, delegating to the wrapped
/// provider otherwise. Unlike the current reading, the forecast lives in App Group
/// storage only so that iPhone widgets can read what the app fetched.
@MainActor
public final class CachingForecastProvider: ForecastProviding {
    private static let key = "forecast"

    private struct Entry: Codable {
        let hours: [ForecastHour]
        let fetchedAt: Date
    }

    private let wrapped: any ForecastProviding
    private let defaults: UserDefaults
    private let ttl: TimeInterval
    private let now: () -> Date

    public init(
        wrapping wrapped: any ForecastProviding,
        defaults: UserDefaults = AppGroup.defaults,
        ttl: TimeInterval,
        now: @escaping () -> Date = Date.init
    ) {
        self.wrapped = wrapped
        self.defaults = defaults
        self.ttl = ttl
        self.now = now
    }

    public func hourlyForecast() async throws -> [ForecastHour] {
        if let data = defaults.data(forKey: Self.key),
           let entry = try? JSONDecoder().decode(Entry.self, from: data),
           now().timeIntervalSince(entry.fetchedAt) < ttl {
            return entry.hours
        }
        let hours = try await wrapped.hourlyForecast()
        if let data = try? JSONEncoder().encode(Entry(hours: hours, fetchedAt: now())) {
            defaults.set(data, forKey: Self.key)
        }
        return hours
    }
}

/// A point in the forecast where the word changes: the first hour of a run of hours
/// that all show the same word.
public struct WordChange: Equatable, Sendable {
    public let date: Date
    public let word: String
    /// Whether the word is a precipitation word rather than a comfort word.
    public let isPrecipitation: Bool
    public let temperatureF: Double
    public let dewpointF: Double
}

/// Collapses forecast hours into the moments the shown word changes, resolving each
/// hour the way the current reading is resolved: precipitation first, otherwise
/// `comfortWord` (the user's custom word for the band, or the engine default).
public func wordChanges(
    in hours: [ForecastHour],
    comfortWord: (_ tempF: Double, _ dewpointF: Double) -> String
) -> [WordChange] {
    var changes: [WordChange] = []
    for hour in hours {
        let word = hour.precipitation?.word ?? comfortWord(hour.temperatureF, hour.dewpointF)
        guard word != changes.last?.word else { continue }
        changes.append(WordChange(
            date: hour.date,
            word: word,
            isPrecipitation: hour.precipitation != nil,
            temperatureF: hour.temperatureF,
            dewpointF: hour.dewpointF
        ))
    }
    return changes
}
