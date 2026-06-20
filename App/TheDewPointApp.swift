import SwiftUI
import ThermalComfort
import WeatherData

@main
struct TheDewPointApp: App {
    var body: some Scene {
        WindowGroup {
            // The live app reads real conditions from WeatherKit. Views are
            // driven by `WeatherProviding`, so previews/tests inject fakes.
            ContentView(model: ConditionsModel(provider: Self.makeProvider()))
        }
    }

    @MainActor
    private static func makeProvider() -> any WeatherProviding {
        #if DEBUG
        // Screenshot/UI hook: set DEWPOINT_FAKE="<tempF>,<dewpointF>[,<precip word>]"
        // to bypass WeatherKit with fixed conditions. A third token forces a
        // precipitation word (e.g. "Snow", "Heavy Rain"). Never in release builds.
        if let env = ProcessInfo.processInfo.environment["DEWPOINT_FAKE"] {
            let parts = env.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, let tempF = Double(parts[0]), let dewpointF = Double(parts[1]) {
                let precipitation = parts.count >= 3 ? ComfortDescriptor(word: parts[2]) : nil
                return FakeWeatherProvider(
                    snapshot: WeatherSnapshot(temperatureF: tempF, dewpointF: dewpointF, precipitation: precipitation, asOf: .now)
                )
            }
        }
        #endif
        // Gate live fetches behind a TTL reading the shared cache, so an app open
        // and the complication's self-fetch don't both hit WeatherKit seconds apart.
        return CachingWeatherProvider(wrapping: WeatherKitProvider(), ttl: 15 * 60)
    }
}
