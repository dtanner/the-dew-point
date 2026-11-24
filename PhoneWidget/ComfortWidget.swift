import SwiftUI
import WeatherData
import WidgetKit

/// The comfort (or precipitation) word: on the Home Screen with the numbers and
/// AQI, the medium size adding what's coming up; on the Lock Screen as a
/// rectangle or the line above the clock.
struct ComfortWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PhoneComfortWord", provider: PhoneProvider()) { entry in
            ComfortWidgetView(entry: entry)
                .containerBackground(for: .widget) { Palette.background }
        }
        .configurationDisplayName("Comfort Word")
        .description("How it feels outside in one word, e.g. “Muggy”.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private struct ComfortWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PhoneEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            if let snapshot = entry.snapshot, let descriptor = entry.descriptor {
                Text("\(descriptor.word) \(degrees(snapshot.temperatureF))")
            } else {
                Text("The Dew Point")
            }
        case .accessoryRectangular:
            LockScreenRectangle(entry: entry)
        case .systemMedium:
            HStack(spacing: 16) {
                NowSummary(entry: entry, wordSize: 32)
                    .frame(maxWidth: 150, alignment: .leading)
                Divider()
                ComingUp(changes: entry.upcoming, hasReading: entry.snapshot != nil)
            }
            // The background is always the app's navy, so lay text out for dark.
            .environment(\.colorScheme, .dark)
        default: // .systemSmall
            NowSummary(entry: entry, wordSize: 36)
                .environment(\.colorScheme, .dark)
        }
    }
}

/// "Now", the word, the numbers beneath, and the AQI — the small widget whole, and
/// the medium widget's left half.
private struct NowSummary: View {
    let entry: PhoneEntry
    let wordSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Now")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let snapshot = entry.snapshot, let descriptor = entry.descriptor {
                Text(descriptor.word)
                    .font(.system(size: wordSize, weight: .bold))
                    .tracking(-0.8)
                    // Precipitation words run long ("Scattered Thunderstorms"):
                    // wrap them, and shrink before truncating.
                    .lineLimit(entry.isPrecipitation ? 3 : 1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(entry.isPrecipitation ? Palette.accent : .primary)
                    .widgetAccentable()
                Text("\(degrees(snapshot.temperatureF)) · dew \(degrees(snapshot.dewpointF))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.system(size: wordSize, weight: .bold))
                Text("Open The Dew Point to load conditions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let aqi = entry.aqi {
                Text("AQI \(Text("\(aqi)").foregroundStyle(AQICategory(aqi: aqi).color).fontWeight(.semibold))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The next few word changes, as on the app's "Coming up" card.
private struct ComingUp: View {
    /// `nil` when the forecast couldn't be loaded.
    let changes: [WordChange]?
    let hasReading: Bool

    var body: some View {
        Group {
            if let changes, !changes.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    ForEach(changes.prefix(4), id: \.date) { change in
                        GridRow {
                            Text(change.date.formatted(.dateTime.hour()))
                                .foregroundStyle(.secondary)
                            Text(change.word)
                                .fontWeight(.semibold)
                                .foregroundStyle(change.isPrecipitation ? Palette.accent : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
                .font(.subheadline)
            } else if hasReading {
                Text(changes == nil ? "Forecast unavailable." : "No change in the forecast.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The Lock Screen rectangle: the word over the numbers. The system draws Lock
/// Screen widgets in its own tint, so nothing here is colored.
private struct LockScreenRectangle: View {
    let entry: PhoneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let snapshot = entry.snapshot, let descriptor = entry.descriptor {
                Text(descriptor.word)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                Text(details(snapshot))
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("—")
                    .font(.system(size: 20, weight: .bold))
                Text("Open the app")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func details(_ snapshot: WeatherSnapshot) -> String {
        let numbers = "\(degrees(snapshot.temperatureF)) · dew \(degrees(snapshot.dewpointF))"
        return entry.aqi.map { "\(numbers) · AQI \($0)" } ?? numbers
    }
}

#if DEBUG
#Preview("Small", as: .systemSmall) {
    ComfortWidget()
} timeline: {
    PhoneEntry.sample
}

#Preview("Medium", as: .systemMedium) {
    ComfortWidget()
} timeline: {
    PhoneEntry.sample
}

#Preview("Lock Screen rectangle", as: .accessoryRectangular) {
    ComfortWidget()
} timeline: {
    PhoneEntry.sample
}

#Preview("Lock Screen inline", as: .accessoryInline) {
    ComfortWidget()
} timeline: {
    PhoneEntry.sample
}
#endif
