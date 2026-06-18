import SwiftUI
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
        // Screenshot/UI hook: set DEWPOINT_FAKE="<tempF>,<dewpointF>" to bypass
        // WeatherKit with fixed conditions. Never present in release builds.
        let env = ProcessInfo.processInfo.environment["DEWPOINT_FAKE"]
        if let parts = env?.split(separator: ",").compactMap({ Double($0) }), parts.count == 2 {
            return FakeWeatherProvider(
                snapshot: WeatherSnapshot(temperatureF: parts[0], dewpointF: parts[1], asOf: .now)
            )
        }
        #endif
        return WeatherKitProvider()
    }
}
