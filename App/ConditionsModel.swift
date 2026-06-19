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
    private let provider: any WeatherProviding

    init(provider: any WeatherProviding) {
        self.provider = provider
    }

    func refresh() async {
        phase = .loading
        do {
            let snapshot = try await provider.currentSnapshot()
            let descriptor = describe(tempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
            phase = .loaded(snapshot, descriptor)
            // The provider cached this reading + its coordinate; nudge the
            // complications so opening the app refreshes them right away too.
            WidgetCenter.shared.reloadAllTimelines()
        } catch is CancellationError {
            // The view went away mid-fetch; leave the current phase untouched.
        } catch {
            phase = .failed(Self.message(for: error))
        }
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
