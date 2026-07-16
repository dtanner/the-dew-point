#if DEBUG
import WeatherData

/// A canned weather source for previews, screenshots, and UI work without
/// WeatherKit. DEBUG-only — never compiled into release builds.
struct FakeWeatherProvider: WeatherProviding {
    let snapshot: WeatherSnapshot
    func currentSnapshot() async throws -> WeatherSnapshot { snapshot }
}

/// Canned AQI, the AirNow counterpart of `FakeWeatherProvider`.
struct FakeAirQualityProvider: AirQualityProviding {
    let aqi: Int
    func currentAQI() async throws -> Int { aqi }
}
#endif
