import Foundation
import ThermalComfort
import WeatherData
import WidgetKit

/// Drives the word and dew point complications from `WidgetReadings`, showing the
/// sample only before the app has ever fetched a reading.
struct ComfortProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComfortEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (ComfortEntry) -> Void) {
        // The gallery needs something instantly; never block it on the network.
        if context.isPreview {
            completion(.sample)
            return
        }
        // WidgetKit hands us `completion` exclusively and calls it once, so handing
        // it off to the fetch task is safe — `nonisolated(unsafe)` tells Swift 6 we
        // vouch for that (the completion handler predates strict concurrency).
        nonisolated(unsafe) let completion = completion
        Task { completion(await Self.currentEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComfortEntry>) -> Void) {
        nonisolated(unsafe) let completion = completion
        Task {
            let entry = await Self.currentEntry()
            let next = Date.now.addingTimeInterval(WidgetReadings.refreshInterval)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    @MainActor
    private static func currentEntry() async -> ComfortEntry {
        guard let snapshot = await WidgetReadings.snapshot() else { return .sample }
        // Date the entry "now", not `snapshot.asOf` (WeatherKit's observation time,
        // which lags real time): this is the current reading and should display as
        // soon as the timeline is built. A past date makes WidgetKit treat the lone
        // entry as already-aged, which undercuts how it schedules the next reload.
        return ComfortEntry(date: .now, descriptor: WidgetReadings.descriptor(for: snapshot), dewpointF: snapshot.dewpointF)
    }
}
