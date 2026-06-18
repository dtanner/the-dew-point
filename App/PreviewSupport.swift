#if DEBUG
import WeatherData

/// A canned weather source for previews, screenshots, and UI work without
/// WeatherKit. DEBUG-only — never compiled into release builds.
struct FakeWeatherProvider: WeatherProviding {
    let snapshot: WeatherSnapshot
    func currentSnapshot() async throws -> WeatherSnapshot { snapshot }
}
#endif
