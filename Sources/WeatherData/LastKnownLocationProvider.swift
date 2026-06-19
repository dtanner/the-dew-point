import CoreLocation

/// A location source that returns CoreLocation's last cached fix without starting
/// a live update stream.
///
/// The app uses `CoreLocationProvider`, which drives `CLLocationUpdate.liveUpdates()`
/// to wait for a fresh fix — appropriate for a foreground screen the user is looking
/// at. A widget extension runs in a tightly time-boxed, low-power context where
/// spinning up location streaming is discouraged and often won't yield a fix before
/// the timeline reload is cut off. So the complication reads `manager.location`, the
/// fix the system already has on hand, and accepts that it may be a little stale —
/// fine for a slowly-changing comfort glance.
///
/// Authorization is inherited from the host app (the widget can't prompt). When
/// the extension has no fix of its own — common — it falls back to the coordinate
/// of the app's last reading (shared via `SnapshotCache`) so the widget can still
/// fetch fresh weather for roughly the right place. Only if there's no fix and no
/// cached coordinate does it throw `.unavailable`.
@MainActor
public final class LastKnownLocationProvider: LocationProviding {
    private let manager = CLLocationManager()
    private let cache: SnapshotCache

    public init(cache: SnapshotCache = SnapshotCache()) {
        self.cache = cache
    }

    public func currentLocation() async throws -> CLLocation {
        if let location = manager.location {
            return location
        }
        if let reading = cache.load() {
            return CLLocation(latitude: reading.latitude, longitude: reading.longitude)
        }
        throw LocationError.unavailable
    }
}
