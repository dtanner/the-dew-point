import SwiftUI
import ThermalComfort
import UIKit
import WeatherData
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
            GeometryReader { geo in
                Text(entry.descriptor.word)
                    .font(.system(size: fontSize(fitting: geo.size.width), weight: .semibold))
                    .lineLimit(1)
                    .widgetAccentable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Base size the word renders at when nothing forces it smaller — roughly
    /// fills the rectangular slot's height on an Ultra.
    private static let baseFontSize: CGFloat = 36

    /// One font size for every word this complication can currently show, computed
    /// so the widest of them fits `width` on a single line. Sizing against the whole
    /// vocabulary — the catalog, saved custom words, and this entry's own word
    /// (which covers WeatherKit precipitation names like "Scattered Thunderstorms")
    /// — keeps the size steady as conditions change on a given watch; it varies
    /// only with the slot width, so bigger watches render bigger text.
    private func fontSize(fitting width: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: Self.baseFontSize, weight: .semibold)
        let words = ComfortDescriptor.all.map(\.word)
            + CustomizationStore().all().map(\.word)
            + [entry.descriptor.word]
        let widest = words
            .map { NSAttributedString(string: $0, attributes: [.font: font]).size().width }
            .max() ?? 0
        return widest <= width ? Self.baseFontSize : Self.baseFontSize * width / widest
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
