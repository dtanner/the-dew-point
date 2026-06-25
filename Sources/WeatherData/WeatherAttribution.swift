import Foundation
import WeatherKit

/// WeatherKit legally requires visible attribution: the Apple Weather mark plus a
/// link to Apple's data-sources legal page. This exposes both so the UI can render
/// them without importing WeatherKit itself, keeping all WeatherKit usage in here.
public struct WeatherAttributionInfo: Sendable {
    /// URL of the Apple Weather combined mark image (logo + "Weather" wordmark),
    /// for the given color scheme. Light backgrounds get the dark mark and vice
    /// versa, per Apple's attribution guidelines.
    public let combinedMarkURL: URL
    /// URL of Apple's required attribution / data-sources legal page.
    public let legalPageURL: URL

    /// Fetches the attribution mark and legal URLs. `darkBackground` picks the
    /// light (white) mark variant designed to sit on dark backgrounds.
    @MainActor
    public static func load(darkBackground: Bool) async throws -> WeatherAttributionInfo {
        let attribution = try await WeatherService.shared.attribution
        return WeatherAttributionInfo(
            combinedMarkURL: darkBackground
                ? attribution.combinedMarkDarkURL
                : attribution.combinedMarkLightURL,
            legalPageURL: attribution.legalPageURL
        )
    }
}
