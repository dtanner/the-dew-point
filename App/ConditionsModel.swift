import Observation
import ThermalComfort
import WeatherData
import WidgetKit

/// Drives the main screen: fetches a weather snapshot, runs it through the
/// comfort engine, and exposes a single phase the view switches on.
@MainActor
@Observable
final class ConditionsModel {
    enum Phase: Equatable {
        case loading
        case loaded(WeatherSnapshot, ComfortDescriptor)
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    /// Current EPA Air Quality Index, or `nil` when there's no source (no AirNow
    /// key in this build) or no reading yet. Deliberately outside `phase`: AQI is
    /// a garnish on the loaded screen, never a reason to show the failure view.
    private(set) var aqi: Int?
    private let provider: any WeatherProviding
    private let airQuality: (any AirQualityProviding)?
    private let customizations: CustomizationStore

    init(
        provider: any WeatherProviding,
        airQuality: (any AirQualityProviding)? = nil,
        customizations: CustomizationStore = CustomizationStore()
    ) {
        self.provider = provider
        self.airQuality = airQuality
        self.customizations = customizations
    }

    func refresh() async {
        phase = .loading
        do {
            let snapshot = try await provider.currentSnapshot()
            phase = .loaded(snapshot, resolvedDescriptor(for: snapshot))
        } catch is CancellationError {
            // The view went away mid-fetch; leave the current phase untouched.
            return
        } catch {
            phase = .failed(Self.message(for: error))
            return
        }
        // AQI rides along after the hero word so a slow AirNow call never delays
        // it. Best-effort: a miss (no nearby station, network blip) just leaves
        // the AQI line off this reading.
        if let airQuality {
            aqi = try? await airQuality.currentAQI()
        }
        // The providers cached these readings (+ the coordinate); nudge the
        // complications so opening the app refreshes them right away too.
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Whether the word currently shown for `snapshot` is a user customization rather
    /// than the engine default. Always false during precipitation, which isn't
    /// band-customizable (no comfort band is on screen).
    func isCustomized(_ snapshot: WeatherSnapshot) -> Bool {
        guard snapshot.precipitation == nil else { return false }
        return customizations.customization(forTempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF) != nil
    }

    /// Saves a custom word for the band `snapshot` falls in, then re-renders. A word
    /// that fails `ComfortWord.validate` is ignored, leaving the current word unchanged.
    func customize(_ rawWord: String, for snapshot: WeatherSnapshot) {
        guard let word = ComfortWord.validate(rawWord) else { return }
        customizations.setWord(word, forTempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
        reresolve(snapshot)
    }

    /// Removes the customization for `snapshot`'s band, reverting to the default word.
    func removeCustomization(for snapshot: WeatherSnapshot) {
        customizations.removeCustomization(forTempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
        reresolve(snapshot)
    }

    private func resolvedDescriptor(for snapshot: WeatherSnapshot) -> ComfortDescriptor {
        snapshot.precipitation ?? customizations.resolvedDescriptor(forTempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
    }

    // Re-render the current reading after a customization change without refetching,
    // and nudge the complications so the watch face matches the app.
    private func reresolve(_ snapshot: WeatherSnapshot) {
        phase = .loaded(snapshot, resolvedDescriptor(for: snapshot))
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func message(for error: Error) -> String {
        switch error {
        case LocationError.denied:
            return "Location is off. Turn it on in Settings to see conditions."
        case LocationError.unavailable:
            return "Couldn’t determine your location."
        default:
            return "Couldn’t load current conditions."
        }
    }
}
