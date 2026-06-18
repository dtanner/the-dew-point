import CoreLocation

/// A one-shot source of the device's current location.
@MainActor
public protocol LocationProviding {
    func currentLocation() async throws -> CLLocation
}

public enum LocationError: Error, Equatable {
    /// The user declined location access.
    case denied
    /// Location services are unavailable or no fix could be obtained.
    case unavailable
}

/// CoreLocation-backed location source using the modern `CLLocationUpdate`
/// async stream. Requests "when in use" authorization on first use, then yields
/// the first usable fix.
@MainActor
public final class CoreLocationProvider: LocationProviding {
    private let manager = CLLocationManager()

    public init() {}

    public func currentLocation() async throws -> CLLocation {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied || update.authorizationDeniedGlobally {
                throw LocationError.denied
            }
            if let location = update.location {
                return location
            }
            // Otherwise we're still waiting on authorization or a first fix;
            // keep consuming until one arrives.
        }
        throw LocationError.unavailable
    }
}
