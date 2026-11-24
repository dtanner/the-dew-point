import Foundation
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
    /// The coming hours, or empty when there's no forecast source (the watch) or no
    /// forecast yet. Best-effort, like `aqi`.
    private(set) var hours: [ForecastHour] = []
    /// Bumped on every change to the custom words. The store lives in UserDefaults,
    /// which Observation can't see, so everything that reads it reads this first to
    /// re-render when a word changes.
    private var customizationsRevision = 0
    private let provider: any WeatherProviding
    private let airQuality: (any AirQualityProviding)?
    private let forecast: (any ForecastProviding)?
    private let customizations: CustomizationStore

    init(
        provider: any WeatherProviding,
        airQuality: (any AirQualityProviding)? = nil,
        forecast: (any ForecastProviding)? = nil,
        customizations: CustomizationStore = CustomizationStore()
    ) {
        self.provider = provider
        self.airQuality = airQuality
        self.forecast = forecast
        self.customizations = customizations
    }

    func refresh() async {
        // Keep a shown reading on screen while refetching: swapping in the spinner
        // would flash it on every return to the app and tear down anything presented
        // from the loaded screen, such as a half-typed custom word.
        if case .loaded = phase {} else {
            phase = .loading
        }
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
        // Same best-effort treatment: a failed forecast keeps the last one.
        if let forecast, let fetched = try? await forecast.hourlyForecast() {
            hours = fetched
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
        return isCustomized(tempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
    }

    /// Whether the band containing these conditions has a custom word.
    func isCustomized(tempF: Double, dewpointF: Double) -> Bool {
        _ = customizationsRevision
        return customizations.customization(forTempF: tempF, dewpointF: dewpointF) != nil
    }

    /// The user's custom words, oldest first.
    var savedCustomizations: [Customization] {
        _ = customizationsRevision
        return customizations.all()
    }

    /// The word shown for `band`: the user's, if set, otherwise `descriptor` (the
    /// band's default).
    func word(for band: ComfortBand, default descriptor: ComfortDescriptor) -> String {
        customWord(for: band) ?? descriptor.word
    }

    /// The user's word for `band`, or `nil` if it has none — even one spelled like
    /// the default counts, so it can still be reset.
    func customWord(for band: ComfortBand) -> String? {
        _ = customizationsRevision
        return customizations.customization(for: band)?.word
    }

    /// The forecast's word changes from the current hour on, each resolved the way
    /// the shown word is (precipitation, then the user's word, then the default).
    var forecastChanges: [WordChange] {
        _ = customizationsRevision
        let currentHourStart = Date.now.addingTimeInterval(-3600)
        return wordChanges(in: hours.filter { $0.date > currentHourStart }) { tempF, dewpointF in
            customizations.resolvedDescriptor(forTempF: tempF, dewpointF: dewpointF).word
        }
    }

    /// The word changes still to come: the forecast's changes after the run the
    /// current word belongs to.
    var upcomingChanges: [WordChange] {
        guard case let .loaded(_, descriptor) = phase else { return [] }
        _ = customizationsRevision
        return upcomingWordChanges(in: hours, now: .now, currentWord: descriptor.word) { tempF, dewpointF in
            customizations.resolvedDescriptor(forTempF: tempF, dewpointF: dewpointF).word
        }
    }

    /// Keeps custom words in step with the user's other devices: pulls the iCloud
    /// copy now, then again each time another device changes it, re-rendering the
    /// shown word and the widgets when anything changed. Runs until cancelled, so
    /// call it from a view's `.task`.
    func syncCustomizations() async {
        NSUbiquitousKeyValueStore.default.synchronize()
        applyCloudCustomizations()
        // Each change carries whether it is iCloud's first download overwriting
        // values this device set early, which the store merges rather than applies.
        let changes = NotificationCenter.default.notifications(
            named: NSUbiquitousKeyValueStore.didChangeExternallyNotification
        ).map { notification in
            notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
                == NSUbiquitousKeyValueStoreInitialSyncChange
        }
        for await initialSync in changes {
            applyCloudCustomizations(initialSync: initialSync)
        }
    }

    private func applyCloudCustomizations(initialSync: Bool = false) {
        guard customizations.syncFromCloud(initialSync: initialSync) else { return }
        customizationsChanged()
    }

    /// The engine's own word for `snapshot`'s band, ignoring any customization, so
    /// an editor can say what the user's word replaces.
    func defaultWord(for snapshot: WeatherSnapshot) -> String {
        describe(tempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF).word
    }

    /// Saves a custom word for the band `snapshot` falls in, then re-renders. A word
    /// that fails `ComfortWord.validate` is ignored, leaving the current word unchanged.
    func customize(_ rawWord: String, for snapshot: WeatherSnapshot) {
        customize(rawWord, tempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
    }

    /// Saves a custom word for the band containing these conditions — any reading
    /// in it, not just the current one — then re-renders. An invalid word is ignored.
    func customize(_ rawWord: String, tempF: Double, dewpointF: Double) {
        guard let word = ComfortWord.validate(rawWord) else { return }
        customizations.setWord(word, forTempF: tempF, dewpointF: dewpointF)
        customizationsChanged()
    }

    /// Removes the customization for `snapshot`'s band, reverting to the default word.
    func removeCustomization(for snapshot: WeatherSnapshot) {
        removeCustomization(tempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
    }

    /// Removes the customization for the band containing these conditions.
    func removeCustomization(tempF: Double, dewpointF: Double) {
        customizations.removeCustomization(forTempF: tempF, dewpointF: dewpointF)
        customizationsChanged()
    }

    private func resolvedDescriptor(for snapshot: WeatherSnapshot) -> ComfortDescriptor {
        snapshot.precipitation ?? customizations.resolvedDescriptor(forTempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
    }

    // Re-render after a custom-word change without refetching, and nudge the
    // complications so the watch face matches the app.
    private func customizationsChanged() {
        customizationsRevision += 1
        if case let .loaded(snapshot, _) = phase {
            phase = .loaded(snapshot, resolvedDescriptor(for: snapshot))
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func message(for error: Error) -> String {
        switch error {
        case LocationError.denied:
            return "Location is off. Turn it on in Settings to see conditions."
        case LocationError.unavailable:
            return "Couldn’t determine your location."
        default:
            #if DEBUG
            // On-device builds have no other window into why a fetch failed
            // (WeatherKit authorization, network); release builds keep it plain.
            return "Couldn’t load current conditions.\n\(error)"
            #else
            return "Couldn’t load current conditions."
            #endif
        }
    }
}
