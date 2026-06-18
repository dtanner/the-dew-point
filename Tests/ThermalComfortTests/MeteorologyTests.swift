import Testing
@testable import ThermalComfort

/// Unit tests for the supporting physics, independent of the descriptor banding.
struct MeteorologyTests {

    @Test func relativeHumidityIs100WhenDewpointEqualsTemp() {
        #expect(abs(Meteorology.relativeHumidity(tempF: 70, dewpointF: 70) - 100) < 0.01)
    }

    @Test func relativeHumidityStaysWithinBounds() {
        for t in stride(from: -30.0, through: 130.0, by: 7) {
            for d in stride(from: -40.0, through: t, by: 7) {
                let rh = Meteorology.relativeHumidity(tempF: t, dewpointF: d)
                #expect(rh >= 0 && rh <= 100)
            }
        }
    }

    // Heat index is only defined when it's both hot and humid; otherwise the app
    // falls back to actual temperature.
    @Test func heatIndexUndefinedWhenCoolOrDry() {
        #expect(Meteorology.heatIndex(tempF: 79, relativeHumidity: 90) == nil)
        #expect(Meteorology.heatIndex(tempF: 95, relativeHumidity: 30) == nil)
    }

    @Test func heatIndexExceedsActualTempInHotHumidAir() {
        let hi = Meteorology.heatIndex(tempF: 95, relativeHumidity: 70)
        #expect(hi != nil)
        #expect((hi ?? 0) > 95)
    }

    @Test func feelsLikeNeverReadsCoolerThanActual() {
        #expect(Meteorology.feelsLike(tempF: 60, relativeHumidity: 90) == 60)
        #expect(Meteorology.feelsLike(tempF: 95, relativeHumidity: 70) > 95)
    }
}
