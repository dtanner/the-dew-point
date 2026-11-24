import SwiftUI

@main
struct TheDewPointPhoneApp: App {
    var body: some Scene {
        WindowGroup {
            // Same model and data sources as the watch app, plus the forecast;
            // only the views differ.
            RootView(model: ConditionsModel(
                provider: Providers.weather(),
                airQuality: Providers.airQuality(),
                forecast: Providers.forecast(),
                customizations: .synced
            ))
        }
    }
}
