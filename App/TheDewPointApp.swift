import SwiftUI
import WeatherData

@main
struct TheDewPointApp: App {
    var body: some Scene {
        WindowGroup {
            // The live app reads real conditions from WeatherKit. Views are
            // driven by `WeatherProviding`, so previews/tests inject fakes.
            ContentView(model: ConditionsModel(provider: WeatherKitProvider()))
        }
    }
}
