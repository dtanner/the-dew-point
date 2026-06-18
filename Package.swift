// swift-tools-version: 6.0
import PackageDescription

// The "brain" of The Dew Point lives here as a platform-agnostic Swift package so
// it can be tested with plain `swift test` (no Xcode, no simulator) and reused by
// both the watch app and the complication. It intentionally has zero knowledge of
// watchOS, WeatherKit, or SwiftUI.
let package = Package(
    name: "DewPoint",
    products: [
        .library(name: "ThermalComfort", targets: ["ThermalComfort"]),
    ],
    targets: [
        .target(name: "ThermalComfort"),
        .testTarget(
            name: "ThermalComfortTests",
            dependencies: ["ThermalComfort"],
            // Golden parity vectors baked from the original reference logic. See
            // ParityTests for how these lock the Swift port to the spec.
            resources: [.copy("Fixtures/parity.csv")]
        ),
    ]
)
