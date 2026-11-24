import SwiftUI
import WeatherData
import WidgetKit

/// The next word changes as a Lock Screen rectangle, made to sit beside the
/// Comfort Word inline line and the Dew Point and AQI circles without repeating
/// any of them.
struct ComingUpWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PhoneComingUp", provider: PhoneProvider()) { entry in
            ComingUpRectangle(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Coming Up")
        .description("When the word changes next, e.g. “3 PM Steamy”.")
        .supportedFamilies([.accessoryRectangular])
    }
}

/// Up to two upcoming changes, one per row: the hour, then the word. The system
/// tints Lock Screen widgets, so nothing here is colored.
private struct ComingUpRectangle: View {
    let entry: PhoneEntry

    var body: some View {
        Group {
            if let changes = entry.upcoming, !changes.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
                    ForEach(changes.prefix(2), id: \.date) { change in
                        GridRow {
                            Text(change.date.formatted(.dateTime.hour()))
                                .font(.system(size: 15, weight: .medium))
                            Text(change.word)
                                .font(.system(size: 20, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .widgetAccentable()
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.descriptor?.word ?? "—")
                        .font(.system(size: 20, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                    Text(fallbackDetail)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Why there are no rows: no reading yet, no forecast, or a steady forecast.
    private var fallbackDetail: String {
        if entry.snapshot == nil { return "Open the app" }
        return entry.upcoming == nil ? "Forecast unavailable" : "No change coming"
    }
}

#if DEBUG
#Preview("Coming up", as: .accessoryRectangular) {
    ComingUpWidget()
} timeline: {
    PhoneEntry.sample
}
#endif
