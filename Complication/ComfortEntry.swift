import Foundation
import ThermalComfort
import WidgetKit

/// One point on a complication's timeline: the comfort to show, the raw dew point
/// (°F) behind it for the numeric complication, and the time the entry becomes
/// relevant (set to "now" when the timeline is built, so WidgetKit orders and ages
/// it from the present rather than the reading's observation time).
struct ComfortEntry: TimelineEntry {
    let date: Date
    let descriptor: ComfortDescriptor
    let dewpointF: Double
}

extension ComfortEntry {
    /// Representative entry for the gallery, previews, and the redacted placeholder.
    /// "Muggy" is a short, clearly readable word; 64° is a muggy-ish dew point.
    static let sample = ComfortEntry(date: .now, descriptor: .muggy, dewpointF: 64)
}
