import SwiftUI
import ThermalComfort
import WeatherData
import WidgetKit

/// Entry point for the iPhone widget extension: the comfort word on the Home and
/// Lock Screens, plus the dew point and AQI as Lock Screen circles, mirroring the
/// watch complications.
@main
struct DewPointPhoneWidgets: WidgetBundle {
    var body: some Widget {
        ComfortWidget()
        DewPointCircleWidget()
        AirQualityCircleWidget()
    }
}

/// One point on an iPhone widget's timeline. Each reading is optional on its own,
/// since they come from separate fetches and one failing shouldn't blank the rest.
struct PhoneEntry: TimelineEntry {
    let date: Date
    /// `nil` before the app has ever fetched conditions.
    let snapshot: WeatherSnapshot?
    /// The word to show for `snapshot`: precipitation, the user's word, or the default.
    let descriptor: ComfortDescriptor?
    let aqi: Int?
    /// The word changes still to come today, for the medium widget; `nil` when the
    /// forecast couldn't be loaded.
    let upcoming: [WordChange]?

    var isPrecipitation: Bool { snapshot?.precipitation != nil }
}

extension PhoneEntry {
    /// Representative entry for the gallery, previews, and the redacted placeholder.
    static let sample: PhoneEntry = {
        let snapshot = WeatherSnapshot(temperatureF: 70, dewpointF: 64, asOf: .now)
        let hourStart = Calendar.current.dateInterval(of: .hour, for: .now)?.start ?? .now
        let readings: [(Double, Double, String?)] = [
            (70, 64, nil), (74, 64, nil), (82, 68, nil), (75, 69, "Thunderstorms"), (71, 62, nil), (66, 54, nil),
        ]
        let hours = readings.enumerated().map { index, reading in
            ForecastHour(
                date: hourStart.addingTimeInterval(Double(index) * 2 * 3600),
                temperatureF: reading.0,
                dewpointF: reading.1,
                precipitation: reading.2.map { ComfortDescriptor(word: $0) }
            )
        }
        return PhoneEntry(
            date: .now,
            snapshot: snapshot,
            descriptor: .muggy,
            aqi: 42,
            upcoming: upcomingWordChanges(in: hours, now: .now, currentWord: "Muggy") { describe(tempF: $0, dewpointF: $1).word }
        )
    }()
}

/// Feeds every iPhone widget from `WidgetReadings`, the same sources and fallbacks
/// as the watch complications.
struct PhoneProvider: TimelineProvider {
    func placeholder(in context: Context) -> PhoneEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (PhoneEntry) -> Void) {
        // The gallery needs something instantly; never block it on the network.
        if context.isPreview {
            completion(.sample)
            return
        }
        // WidgetKit calls `completion` once and hands it over exclusively, so
        // passing it into the task is safe; the handler predates strict concurrency.
        nonisolated(unsafe) let completion = completion
        Task { completion(await Self.currentEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhoneEntry>) -> Void) {
        nonisolated(unsafe) let completion = completion
        Task {
            let entry = await Self.currentEntry()
            // Reload by the next listed change too, so the medium widget doesn't keep
            // showing it as "coming up" once its hour has started.
            let nextChange = entry.upcoming?.map(\.date).first { $0 > .now }
            let next = min(Date.now.addingTimeInterval(WidgetReadings.refreshInterval), nextChange ?? .distantFuture)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    @MainActor
    private static func currentEntry() async -> PhoneEntry {
        let aqi = await WidgetReadings.aqi()
        guard let snapshot = await WidgetReadings.snapshot() else {
            return PhoneEntry(date: .now, snapshot: nil, descriptor: nil, aqi: aqi, upcoming: nil)
        }
        let descriptor = WidgetReadings.descriptor(for: snapshot)
        let store = CustomizationStore()
        let upcoming = await WidgetReadings.forecast().map { hours in
            upcomingWordChanges(in: hours, now: .now, currentWord: descriptor.word) {
                store.resolvedDescriptor(forTempF: $0, dewpointF: $1).word
            }
        }
        // Dated now, not at the observation time, so WidgetKit shows it right away.
        return PhoneEntry(date: .now, snapshot: snapshot, descriptor: descriptor, aqi: aqi, upcoming: upcoming)
    }
}

/// A °F reading as a rounded whole number with a degree sign, e.g. "64°".
func degrees(_ value: Double) -> String {
    "\(Int(value.rounded()))°"
}
