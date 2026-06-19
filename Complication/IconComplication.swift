import SwiftUI
import WidgetKit

/// Complication that shows the comfort as a single icon. Uses the SF Symbol
/// rendition (not the emoji) because emoji render as flat gray on tinted faces.
/// Drop it in a corner or circular slot of the Modular face.
struct IconComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ComfortIcon", provider: ComfortProvider()) { entry in
            IconEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("The Dew Point — Icon")
        .description("Shows the current comfort as a single icon.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

private struct IconEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComfortEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground() // the standard faint dial behind the symbol
                symbol
            }
        default: // .accessoryCorner
            symbol
        }
    }

    private var symbol: some View {
        Image(systemName: entry.descriptor.symbol)
            .font(.title2)
            .widgetAccentable()
    }
}

#if DEBUG
#Preview("Icon — circular", as: .accessoryCircular) {
    IconComplication()
} timeline: {
    ComfortEntry.sample
}

#Preview("Icon — corner", as: .accessoryCorner) {
    IconComplication()
} timeline: {
    ComfortEntry.sample
}
#endif
