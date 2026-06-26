import SwiftUI
import WidgetKit

/// Complication that shows the current dew point as a bare °F number, e.g. "64°".
/// Lives in the round corner/sub-dial slots; pair it with the Word complication for
/// a "what it feels like + the number behind it" glance.
struct DewpointComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DewpointValue", provider: ComfortProvider()) { entry in
            DewpointEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("The Dew Point — Dew Point")
        .description("Shows the current dew point as a number, e.g. “64°”.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

private struct DewpointEntryView: View {
    let entry: ComfortEntry

    // Bare °F integer, matching how the app screen renders dew point.
    private var text: String { "\(Int(entry.dewpointF.rounded()))°" }

    var body: some View {
        Text(text)
            .font(.title2.weight(.semibold))
            .minimumScaleFactor(0.6) // so a three-digit "-12°" style value still fits
            .widgetAccentable()
    }
}

#if DEBUG
#Preview("Dew point — circular", as: .accessoryCircular) {
    DewpointComplication()
} timeline: {
    ComfortEntry.sample
}

#Preview("Dew point — corner", as: .accessoryCorner) {
    DewpointComplication()
} timeline: {
    ComfortEntry.sample
}
#endif
