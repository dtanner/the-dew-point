import SwiftUI
import WeatherData
import WidgetKit

/// Complication that shows the current EPA Air Quality Index, e.g. "42". Fits the
/// same round corner/sub-dial slots as the dew point number, plus the rectangular
/// slot (labeled "AQI 42" there, since a bare number in the wide slot reads as
/// nothing in particular). The data comes from AirNow (WeatherKit has no air
/// quality), so it needs the AirNow API key baked into the build — without one it
/// shows the last cached value or a dash.
struct AQIComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AirQualityValue", provider: AQIProvider()) { entry in
            AQIEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Air Quality")
        .description("Shows the current EPA air quality index, e.g. “42”.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

/// One point on the AQI complication's timeline. Separate from `ComfortEntry`
/// because the two readings come from different sources on independent fetches —
/// tying them together would make either one's failure blank the other.
struct AQIEntry: TimelineEntry {
    let date: Date
    /// `nil` when there has never been a reading to show (no API key baked in, or
    /// no fetch has succeeded yet); renders as a dash.
    let aqi: Int?
}

extension AQIEntry {
    /// Representative entry for the gallery, previews, and the redacted placeholder.
    static let sample = AQIEntry(date: .now, aqi: 42)
}

/// Timeline provider for the AQI complication, mirroring `ComfortProvider`:
/// self-fetch on a ~30-minute cadence through the TTL gate, fall back to the last
/// cached reading when a live fetch isn't possible, so the glance never goes blank.
struct AQIProvider: TimelineProvider {
    func placeholder(in context: Context) -> AQIEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (AQIEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        nonisolated(unsafe) let completion = completion
        Task { completion(await Self.currentEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AQIEntry>) -> Void) {
        nonisolated(unsafe) let completion = completion
        Task {
            let entry = await Self.currentEntry()
            let next = Date.now.addingTimeInterval(30 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    @MainActor
    private static func currentEntry() async -> AQIEntry {
        // No key in this build (Secrets.xcconfig was empty or absent): live
        // fetching is off, so show whatever the cache last saw — usually nothing.
        guard let key = AirNowProvider.bundledAPIKey else {
            return AQIEntry(date: .now, aqi: AirQualityCache().load()?.aqi)
        }
        let provider = CachingAirQualityProvider(
            wrapping: AirNowProvider(apiKey: key, location: LastKnownLocationProvider()),
            ttl: 30 * 60
        )
        if let aqi = try? await provider.currentAQI() {
            return AQIEntry(date: .now, aqi: aqi)
        }
        return AQIEntry(date: .now, aqi: AirQualityCache().load()?.aqi)
    }
}

private struct AQIEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AQIEntry

    private var number: String { entry.aqi.map(String.init) ?? "—" }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            // The wide slot gets an "AQI" label; the round slots stay a bare
            // number because there's no room for one there. Fixed size: the
            // longest value ("AQI 999") fits every watch's slot, so nothing to
            // compute (unlike the word complication's open-ended vocabulary).
            Text("AQI \(number)")
                .font(.system(size: 30, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
        default: // .accessoryCircular, .accessoryCorner
            Text(number)
                .font(.title2.weight(.semibold))
                .minimumScaleFactor(0.6) // so a three-digit smoke-event value still fits
                .widgetAccentable()
        }
    }
}

#if DEBUG
#Preview("AQI — circular", as: .accessoryCircular) {
    AQIComplication()
} timeline: {
    AQIEntry.sample
}

#Preview("AQI — corner", as: .accessoryCorner) {
    AQIComplication()
} timeline: {
    AQIEntry.sample
}

#Preview("AQI — rectangular", as: .accessoryRectangular) {
    AQIComplication()
} timeline: {
    AQIEntry.sample
}
#endif
