import Foundation
import ThermalComfort
import WidgetKit

/// One point on a complication's timeline: the comfort to show and the time the
/// entry becomes relevant (set to "now" when the timeline is built, so WidgetKit
/// orders and ages it from the present rather than the reading's observation time).
struct ComfortEntry: TimelineEntry {
    let date: Date
    let descriptor: ComfortDescriptor
}

extension ComfortEntry {
    /// Representative entry for the gallery, previews, and the redacted placeholder.
    /// "Muggy" is a short, clearly readable word.
    static let sample = ComfortEntry(date: .now, descriptor: .muggy)
}
