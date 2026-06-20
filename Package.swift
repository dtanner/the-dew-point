// swift-tools-version: 6.0
import PackageDescription

// The "brain" of The Dew Point lives here as a platform-agnostic Swift package so
// it can be tested with plain `swift test` (no Xcode, no simulator) and reused by
// both the watch app and the complication. It intentionally has zero knowledge of
// watchOS, WeatherKit, or SwiftUI.
let package = Package(
    name: "DewPoint",
    // Floors are set low enough that the pure engine still tests on the macOS
    // host via `swift test`; the watch app sets its own (higher) deployment
    // target. watchOS 11 / macOS 15 is the floor for the CLLocationUpdate
    // authorization properties used in WeatherData.
    platforms: [.watchOS(.v11), .macOS(.v15), .iOS(.v17)],
    products: [
        .library(name: "ThermalComfort", targets: ["ThermalComfort"]),
        .library(name: "WeatherData", targets: ["WeatherData"]),
    ],
    targets: [
        .target(name: "ThermalComfort"),
        // The data layer: turns location into current temperature + dew point via
        // WeatherKit, behind a protocol so the UI can be driven by fakes. Depends on
        // ThermalComfort to reuse `ComfortDescriptor` for the precipitation override
        // carried on `WeatherSnapshot`; the dependency direction stays data-layer →
        // engine, so the engine itself remains free of WeatherKit/UI deps.
        .target(name: "WeatherData", dependencies: ["ThermalComfort"]),
        .testTarget(
            name: "ThermalComfortTests",
            dependencies: ["ThermalComfort"],
            // Golden parity vectors baked from the original reference logic. See
            // ParityTests for how these lock the Swift port to the spec.
            resources: [.copy("Fixtures/parity.csv")]
        ),
        .testTarget(name: "WeatherDataTests", dependencies: ["WeatherData", "ThermalComfort"]),
    ]
)
