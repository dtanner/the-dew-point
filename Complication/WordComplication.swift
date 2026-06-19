import SwiftUI
import WidgetKit

/// Complication that shows the comfort as a single word, e.g. "Muggy". Drop it in
/// the rectangular slot of the Modular face (or an inline slot on other faces).
struct WordComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ComfortWord", provider: ComfortProvider()) { entry in
            WordEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("The Dew Point — Word")
        .description("Shows the current comfort in one word, e.g. “Muggy”.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

private struct WordEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComfortEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            // Inline is a single styled line the system lays out; just hand it text.
            Text(entry.descriptor.word)
        default: // .accessoryRectangular
            Text(entry.descriptor.word)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.6) // so "Comfortable" still fits
                .widgetAccentable()
        }
    }
}

#if DEBUG
#Preview("Word — rectangular", as: .accessoryRectangular) {
    WordComplication()
} timeline: {
    ComfortEntry.sample
}

#Preview("Word — inline", as: .accessoryInline) {
    WordComplication()
} timeline: {
    ComfortEntry.sample
}
#endif
