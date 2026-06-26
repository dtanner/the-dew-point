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
            // TTL gate means an app fetch the complication's reload was triggered by
            // is served straight from the cache the app just wrote — no second
            // WeatherKit call. The wrapped provider re-caches on a real fetch,
            // keeping the fallback current.
            let provider = CachingWeatherProvider(
                wrapping: WeatherKitProvider(location: LastKnownLocationProvider()),
                ttl: 30 * 60
            )
            return entry(for: try await provider.currentSnapshot())
        } catch {
            if let cached = SnapshotCache().load() {
                return entry(for: cached.snapshot)
            }
            return .sample
        }
    }

    private static func entry(for snapshot: WeatherSnapshot) -> ComfortEntry {
        // Date the entry "now", not `snapshot.asOf` (WeatherKit's observation time,
        // which lags real time): this is the current reading and should display as
        // soon as the timeline is built. A past date makes WidgetKit treat the lone
        // entry as already-aged, which undercuts how it schedules the next reload.
        // Resolve through the shared store so the complication honors the user's
        // per-band custom words exactly as the app does.
        ComfortEntry(
            date: .now,
            descriptor: snapshot.precipitation ?? CustomizationStore().resolvedDescriptor(forTempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
        )
    }
}
