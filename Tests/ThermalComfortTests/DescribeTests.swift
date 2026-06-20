import Foundation
import Testing
@testable import ThermalComfort

/// Focused, human-readable cases that document intent the bulk parity grid can't:
/// the spec's worked examples, dew-point clamping, and the boundaries of the
/// valid domain.
struct DescribeTests {

    // The two worked examples from the spec's Cool section — same dew point,
    // different temperature, deliberately different result.
    @Test func coolBandExamplesFromSpec() {
        #expect(describe(tempF: 57, dewpointF: 55) == .clammy)
        #expect(describe(tempF: 63, dewpointF: 55) == .comfortable)
    }

    // Dew point above temperature is unphysical; it must clamp to temp and not
    // change the verdict relative to dp == temp.
    @Test func dewpointClampsToTemperature() {
        let clamped = describe(tempF: 70, dewpointF: 95)
        let atTemp = describe(tempF: 70, dewpointF: 70)
        #expect(clamped == atTemp)
    }

    // "Warm" spans two bands the spec once distinguished only by emoji; with the
    // icon channel gone they collapse to one descriptor. Lock that both bands
    // still produce "Warm" so a future re-split is a deliberate, visible change.
    @Test func warmBandsBothMapToWarm() {
        #expect(describe(tempF: 77, dewpointF: 50) == .warm)
        #expect(describe(tempF: 82, dewpointF: 30) == .warm)
    }

    @Test func extremeColdAndHeatEndpoints() {
        #expect(describe(tempF: -30, dewpointF: -40) == .bitter)
        #expect(describe(tempF: 130, dewpointF: 80) == .deadly)
    }

    // ComfortDescriptor rides inside the cached WeatherSnapshot as the precipitation
    // override, so it must survive a JSON round-trip intact.
    @Test func descriptorRoundTripsThroughCodable() throws {
        let original = ComfortDescriptor(word: "Heavy Rain")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ComfortDescriptor.self, from: data)
        #expect(decoded == original)
    }
}
