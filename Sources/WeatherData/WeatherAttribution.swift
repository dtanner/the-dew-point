import Foundation
import WeatherKit

/// WeatherKit legally requires visible attribution. This exposes the data-source
/// legal page URL so the UI can link to it without importing WeatherKit itself,
/// keeping all WeatherKit usage inside this module.
public enum WeatherAttributionInfo {
    /// URL of Apple's required attribution / data-sources legal page.
    @MainActor
    public static func legalPageURL() async throws -> URL {
        try await WeatherService.shared.attribution.legalPageURL
    }
}
