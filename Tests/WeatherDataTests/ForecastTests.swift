import Foundation
import Testing
import ThermalComfort
@testable import WeatherData

/// The forecast reduces to the moments the shown word changes, resolved the same
/// way as the current reading, and is fetched at most once per TTL window.
@MainActor
struct ForecastTests {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func hour(_ offset: Int, _ tempF: Double, _ dewpointF: Double, _ precip: String? = nil) -> ForecastHour {
        ForecastHour(
            date: start.addingTimeInterval(Double(offset) * 3600),
            temperatureF: tempF,
            dewpointF: dewpointF,
            precipitation: precip.map { ComfortDescriptor(word: $0) }
        )
    }

    private func engineWord(_ tempF: Double, _ dewpointF: Double) -> String {
        describe(tempF: tempF, dewpointF: dewpointF).word
    }

    @Test func collapsesRunsOfTheSameWord() {
        let hours = [hour(0, 70, 64), hour(1, 72, 65), hour(2, 82, 68), hour(3, 70, 60)]
        let changes = wordChanges(in: hours, comfortWord: engineWord)
        #expect(changes.map(\.word) == ["Muggy", "Stifling", "Sticky"])
        #expect(changes.map(\.date) == [hours[0].date, hours[2].date, hours[3].date])
    }

    @Test func precipitationOverridesTheComfortWord() {
        let hours = [hour(0, 70, 64), hour(1, 75, 69, "Thunderstorms"), hour(2, 73, 66)]
        let changes = wordChanges(in: hours, comfortWord: engineWord)
        #expect(changes.map(\.word) == ["Muggy", "Thunderstorms", "Muggy"])
        #expect(changes.map(\.isPrecipitation) == [false, true, false])
    }

    @Test func customWordsApplyAndCanMergeRuns() {
        // Both bands renamed to the same word read as one run.
        let hours = [hour(0, 70, 64), hour(1, 70, 60)]
        let changes = wordChanges(in: hours) { _, _ in "Soup" }
        #expect(changes.map(\.word) == ["Soup"])
    }

    @Test func emptyForecastHasNoChanges() {
        #expect(wordChanges(in: [], comfortWord: engineWord).isEmpty)
    }

    @Test func cachingProviderFetchesOncePerWindow() async throws {
        let source = CountingForecast(hours: [hour(0, 70, 64)])
        var now = start
        let defaults = UserDefaults(suiteName: "ForecastTests.\(UUID().uuidString)")!
        let provider = CachingForecastProvider(wrapping: source, defaults: defaults, ttl: 600) { now }
        _ = try await provider.hourlyForecast()
        now = start.addingTimeInterval(300)
        let cached = try await provider.hourlyForecast()
        #expect(source.fetches == 1)
        #expect(cached == source.hours)
        now = start.addingTimeInterval(601)
        _ = try await provider.hourlyForecast()
        #expect(source.fetches == 2)
    }
}

@MainActor
private final class CountingForecast: ForecastProviding {
    let hours: [ForecastHour]
    private(set) var fetches = 0

    init(hours: [ForecastHour]) { self.hours = hours }

    func hourlyForecast() async throws -> [ForecastHour] {
        fetches += 1
        return hours
    }
}
