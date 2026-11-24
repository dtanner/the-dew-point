import SwiftUI
import WatchKit
import WeatherData
import WidgetKit

@main
struct TheDewPointApp: App {
    // watchOS only honors a complication's `.after` reload hint within a limited
    // background budget, so left alone the watch face only refreshes when the app
    // is opened. The delegate below schedules our own background app refresh to
    // fetch fresh weather (in the app process, which has full location access and a
    // real execution window — unlike the time-boxed widget extension) and then
    // reload the complications.
    @WKApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            // The live app reads real conditions from WeatherKit (and AQI from
            // AirNow). Views are driven by the providing protocols, so
            // previews/tests inject fakes.
            ContentView(model: ConditionsModel(
                provider: Providers.weather(),
                airQuality: Providers.airQuality(),
                customizations: .synced
            ))
        }
    }

    /// How far out to ask the system to wake us. watchOS throttles background
    /// refresh to roughly hourly for an app with an active complication, so this is
    /// a lower bound the system rounds up — it won't make us fire more often.
    fileprivate static let refreshInterval: TimeInterval = 30 * 60

    /// Asks watchOS to wake the app for a background refresh after `refreshInterval`.
    fileprivate static func scheduleBackgroundRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date.now.addingTimeInterval(refreshInterval),
            userInfo: nil
        ) { _ in
            // Best-effort: if scheduling failed there's nothing useful to do here,
            // and the next app launch re-seeds the chain via the delegate.
        }
    }

    /// Background-refresh work: fetch fresh weather (which writes the shared cache),
    /// push the new reading to the complications, then schedule the next wake-up so
    /// the chain continues without the app being opened.
    @MainActor
    fileprivate static func handleBackgroundRefresh() async {
        defer { scheduleBackgroundRefresh() }
        // Failed fetches (no fix, no network) just leave the caches as-is; the
        // complications keep showing the last good readings until the next wake-up.
        _ = try? await Providers.weather(location: LastKnownLocationProvider()).currentSnapshot()
        if let aqiProvider = Providers.airQuality(location: LastKnownLocationProvider()) {
            _ = try? await aqiProvider.currentAQI()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Drives background app refresh. SwiftUI's `App` has no launch/background-task
/// hooks on watchOS, so we attach a `WKApplicationDelegate`: seed the refresh chain
/// at launch, and on each scheduled wake-up do the fetch+reload work, then mark the
/// task complete (required, or watchOS stops granting us background time).
final class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        TheDewPointApp.scheduleBackgroundRefresh()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            guard let refresh = task as? WKApplicationRefreshBackgroundTask else {
                task.setTaskCompletedWithSnapshot(false)
                continue
            }
            Task { @MainActor in
                await TheDewPointApp.handleBackgroundRefresh()
                refresh.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
