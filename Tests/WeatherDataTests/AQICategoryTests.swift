import Testing
@testable import WeatherData

/// The category mapping's contract is the exact EPA breakpoints — an
/// off-by-one here would show the wrong severity color on the watch face.
struct AQICategoryTests {

    @Test func boundariesMatchEPABreakpoints() {
        #expect(AQICategory(aqi: 0) == .good)
        #expect(AQICategory(aqi: 50) == .good)
        #expect(AQICategory(aqi: 51) == .moderate)
        #expect(AQICategory(aqi: 100) == .moderate)
        #expect(AQICategory(aqi: 101) == .unhealthyForSensitiveGroups)
        #expect(AQICategory(aqi: 150) == .unhealthyForSensitiveGroups)
        #expect(AQICategory(aqi: 151) == .unhealthy)
        #expect(AQICategory(aqi: 200) == .unhealthy)
        #expect(AQICategory(aqi: 201) == .veryUnhealthy)
        #expect(AQICategory(aqi: 300) == .veryUnhealthy)
        #expect(AQICategory(aqi: 301) == .hazardous)
        #expect(AQICategory(aqi: 500) == .hazardous)
    }
}
