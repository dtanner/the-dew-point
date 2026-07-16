import CoreLocation
import Foundation
import Testing
@testable import WeatherData

/// The provider's contract: report the worst pollutant's AQI, drop AirNow's -1
/// "couldn't compute" markers, surface "no station nearby" as an error rather
/// than a fake number, and cache what it returns.
@MainActor
struct AirNowProviderTests {

    private final class FixedLocation: LocationProviding {
        func currentLocation() async throws -> CLLocation {
            CLLocation(latitude: 44.98, longitude: -93.26)
        }
    }

    private func makeCache() -> AirQualityCache {
        AirQualityCache(defaults: UserDefaults(suiteName: "AirNowProviderTests.\(UUID().uuidString)")!)
    }

    private func makeProvider(returning json: String, cache: AirQualityCache? = nil) -> AirNowProvider {
        AirNowProvider(
            apiKey: "test-key",
            location: FixedLocation(),
            cache: cache ?? makeCache(),
            fetch: { _ in Data(json.utf8) }
        )
    }

    /// Trimmed but real-shaped AirNow response: one element per pollutant, with
    /// the fields the provider ignores still present.
    private let twoPollutants = """
    [
      {"DateObserved":"2026-07-15 ","HourObserved":10,"LocalTimeZone":"CST",
       "ReportingArea":"Minneapolis-St. Paul","StateCode":"MN",
       "ParameterName":"O3","AQI":35,"Category":{"Number":1,"Name":"Good"}},
      {"DateObserved":"2026-07-15 ","HourObserved":10,"LocalTimeZone":"CST",
       "ReportingArea":"Minneapolis-St. Paul","StateCode":"MN",
       "ParameterName":"PM2.5","AQI":52,"Category":{"Number":2,"Name":"Moderate"}}
    ]
    """

    @Test func reportsWorstPollutant() async throws {
        let provider = makeProvider(returning: twoPollutants)
        #expect(try await provider.currentAQI() == 52)
    }

    @Test func ignoresUncomputedPollutants() async throws {
        let provider = makeProvider(returning: """
        [{"ParameterName":"O3","AQI":-1},{"ParameterName":"PM2.5","AQI":40}]
        """)
        #expect(try await provider.currentAQI() == 40)
    }

    @Test func throwsWhenNoStationReports() async throws {
        let provider = makeProvider(returning: "[]")
        await #expect(throws: AirQualityError.noData) {
            try await provider.currentAQI()
        }
    }

    @Test func throwsWhenEveryPollutantIsUncomputed() async throws {
        let provider = makeProvider(returning: """
        [{"ParameterName":"O3","AQI":-1}]
        """)
        await #expect(throws: AirQualityError.noData) {
            try await provider.currentAQI()
        }
    }

    @Test func cachesSuccessfulReading() async throws {
        let cache = makeCache()
        let provider = makeProvider(returning: twoPollutants, cache: cache)
        _ = try await provider.currentAQI()
        #expect(cache.load()?.aqi == 52)
    }

    @Test func requestCarriesCoordinateKeyAndFormat() {
        let url = AirNowProvider.url(
            for: CLLocationCoordinate2D(latitude: 44.98, longitude: -93.26),
            apiKey: "test-key"
        )
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        #expect(url.host() == "www.airnowapi.org")
        #expect(value("latitude") == "44.98")
        #expect(value("longitude") == "-93.26")
        #expect(value("API_KEY") == "test-key")
        #expect(value("format") == "application/json")
    }
}
