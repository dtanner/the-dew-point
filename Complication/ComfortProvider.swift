import Foundation
import ThermalComfort
import WeatherData
import WidgetKit

/// Drives both complications: fetches current conditions, runs them through the
/// comfort engine, and falls back to the last cached reading when a live fetch
/// isn't possible (no network, no location fix, or a cut-off refresh) so the glance
/// never goes blank.
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
            // Comfort changes slowly, so one entry plus a ~30-min refresh hint is
            // plenty. WidgetKit may defer the reload to protect its budget.
            let next = Date.now.addingTimeInterval(30 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    // WeatherKitProvider / LastKnownLocationProvider are @MainActor, so the fetch
    // hops to the main actor; `describe` is pure and fine to call from there.
    @MainActor
    private static func currentEntry() async -> ComfortEntry {
        do {
            // Self-fetch fresh weather, locating via the device's own fix or, if the
            // extension has none, the coordinate from the app's last reading. The
            // provider re-caches on success, keeping the fallback current.
            let provider = WeatherKitProvider(location: LastKnownLocationProvider())
            return entry(for: try await provider.currentSnapshot())
        } catch {
            if let cached = SnapshotCache().load() {
                return entry(for: cached.snapshot)
            }
            return .sample
        }
    }

    private static func entry(for snapshot: WeatherSnapshot) -> ComfortEntry {
        ComfortEntry(
            date: snapshot.asOf,
            descriptor: describe(tempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
        )
    }
}
