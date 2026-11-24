import SwiftUI
import WidgetKit

/// The dew point as a Lock Screen circle, like the watch's dew point complication.
struct DewPointCircleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PhoneDewPoint", provider: PhoneProvider()) { entry in
            LabeledCircle(label: "DEW", value: entry.snapshot.map { degrees($0.dewpointF) })
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Dew Point")
        .description("The current dew point, e.g. “64°”.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// The EPA air quality index as a Lock Screen circle, like the watch's AQI
/// complication.
struct AirQualityCircleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PhoneAirQuality", provider: PhoneProvider()) { entry in
            LabeledCircle(label: "AQI", value: entry.aqi.map(String.init))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Air Quality")
        .description("The current EPA air quality index, e.g. “42”.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// A small label over a number on the system's circle backdrop; a dash when
/// there's no reading.
private struct LabeledCircle: View {
    let label: String
    let value: String?

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                Text(value ?? "—")
                    .font(.system(size: 22, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
            }
            .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Dew point", as: .accessoryCircular) {
    DewPointCircleWidget()
} timeline: {
    PhoneEntry.sample
}

#Preview("Air quality", as: .accessoryCircular) {
    AirQualityCircleWidget()
} timeline: {
    PhoneEntry.sample
}
#endif
