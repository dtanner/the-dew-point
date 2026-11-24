#if DEBUG
import Foundation
import ThermalComfort
import WeatherData

/// A canned weather source for previews, screenshots, and UI work without
/// WeatherKit. DEBUG-only — never compiled into release builds.
struct FakeWeatherProvider: WeatherProviding {
    let snapshot: WeatherSnapshot
    func currentSnapshot() async throws -> WeatherSnapshot { snapshot }
}

/// A canned forecast. `sampleDay()` is a humid summer day with an afternoon
/// storm, starting at the current hour, so previews and the simulator show every
/// kind of word change.
struct FakeForecastProvider: ForecastProviding {
    let hours: [ForecastHour]
    func hourlyForecast() async throws -> [ForecastHour] { hours }

    static func sampleDay(from start: Date = .now) -> FakeForecastProvider {
        let hourStart = Calendar.current.dateInterval(of: .hour, for: start)?.start ?? start
        // (temp °F, dew point °F, precipitation) for each hour from now.
        let readings: [(Double, Double, String?)] = [
            (70, 64, nil), (72, 64, nil), (74, 64, nil), (77, 65, nil), (79, 66, nil),
            (82, 68, nil), (75, 69, "Thunderstorms"), (73, 67, nil), (73, 66, nil), (71, 63, nil),
            (70, 61, nil), (68, 58, nil), (67, 55, nil), (66, 53, nil), (64, 52, nil),
            (63, 51, nil), (62, 50, nil), (61, 49, nil), (61, 48, nil), (62, 48, nil),
            (64, 49, nil), (67, 51, nil), (70, 53, nil), (73, 55, nil),
        ]
        let hours = readings.enumerated().map { index, reading in
            ForecastHour(
                date: hourStart.addingTimeInterval(Double(index) * 3600),
                temperatureF: reading.0,
                dewpointF: reading.1,
                precipitation: reading.2.map { ComfortDescriptor(word: $0) }
            )
        }
        return FakeForecastProvider(hours: hours)
    }
}

/// Canned AQI, the AirNow counterpart of `FakeWeatherProvider`.
struct FakeAirQualityProvider: AirQualityProviding {
    let aqi: Int
    func currentAQI() async throws -> Int { aqi }
}
#endif
