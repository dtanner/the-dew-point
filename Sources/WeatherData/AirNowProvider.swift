import CoreLocation
import Foundation

/// Fetches the current EPA Air Quality Index from AirNow for the device location.
///
/// WeatherKit doesn't expose air quality at all (neither the framework nor the
/// REST API), so this is a second data source alongside `WeatherKitProvider`.
/// AirNow is the EPA's official observation feed: station-based readings, US-only
/// coverage, keyed access (free key from https://docs.airnowapi.org). The key is
/// injected by the caller — see `bundledAPIKey` for how the app and widget carry
/// it without it living in this public repo.
@MainActor
public final class AirNowProvider: AirQualityProviding {
    /// One pollutant's observation in AirNow's current-observations response
    /// (the array has one element per pollutant: OZONE, PM2.5, PM10, …). Only the
    /// field we read; the rest of the payload is ignored.
    private struct Observation: Decodable {
        let nowcastAQI: Int
    }

    /// AirNow's error body. It arrives with HTTP 200 in place of the observation
    /// array, e.g. when no monitor is within range of the coordinate.
    private struct ServiceErrorBody: Decodable {
        struct Message: Decodable { let Message: String }
        let WebServiceError: [Message]
    }

    private let apiKey: String
    private let location: any LocationProviding
    private let cache: AirQualityCache
    private let fetch: @MainActor (URL) async throws -> Data

    // `location` defaults to nil for the same reason as WeatherKitProvider's:
    // default argument values can't construct a @MainActor type. `fetch` is
    // injectable so tests exercise parsing without a network.
    public init(
        apiKey: String,
        location: (any LocationProviding)? = nil,
        cache: AirQualityCache = AirQualityCache(),
        fetch: (@MainActor (URL) async throws -> Data)? = nil
    ) {
        self.apiKey = apiKey
        self.location = location ?? CoreLocationProvider()
        self.cache = cache
        self.fetch = fetch ?? { try await URLSession.shared.data(from: $0).0 }
    }

    /// The AirNow API key carried in the target's Info.plist, wired there from the
    /// git-ignored Config/Secrets.xcconfig (the repo is public, so the key never
    /// appears in source or in project.yml). `nil` when unset — callers treat that
    /// as "air quality feature off" and the rest of the app works normally.
    public static var bundledAPIKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "AirNowAPIKey") as? String,
              !key.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        return key
    }

    public func currentAQI() async throws -> Int {
        let place = try await location.currentLocation()
        let data = try await fetch(Self.url(for: place.coordinate, apiKey: apiKey))
        let aqi = try Self.overallAQI(from: data)
        // Remember the reading so the complication can fall back to it when a
        // live fetch fails, and so the TTL gate can serve it while fresh.
        cache.save(CachedAirQuality(aqi: aqi, fetchedAt: Date()))
        return aqi
    }

    static func url(for coordinate: CLLocationCoordinate2D, apiKey: String) -> URL {
        // AirNow picks the reporting area itself (monitors within 50 miles);
        // this service takes no search-radius parameter.
        var components = URLComponents(string: "https://www.airnowapi.org/aq/observation/current/ziplatlong/")!
        components.queryItems = [
            .init(name: "format", value: "application/json"),
            .init(name: "latitude", value: String(coordinate.latitude)),
            .init(name: "longitude", value: String(coordinate.longitude)),
            .init(name: "API_KEY", value: apiKey),
        ]
        return components.url!
    }

    /// The overall AQI is the worst (highest) of the per-pollutant observations —
    /// the same rule the EPA uses to headline a reporting area. AirNow reports a
    /// pollutant it couldn't compute as -1, so those are dropped rather than ever
    /// winning the max.
    static func overallAQI(from data: Data) throws -> Int {
        let decoder = JSONDecoder()
        if let body = try? decoder.decode(ServiceErrorBody.self, from: data) {
            throw AirQualityError.service(body.WebServiceError.map(\.Message).joined(separator: " "))
        }
        let observations = try decoder.decode([Observation].self, from: data)
        guard let worst = observations.map(\.nowcastAQI).filter({ $0 >= 0 }).max() else {
            throw AirQualityError.noData
        }
        return worst
    }
}
