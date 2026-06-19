import Foundation
import ThermalComfort
import WidgetKit

/// One point on a complication's timeline: the comfort to show and the time the
/// underlying reading is from (used as the entry date so the system can order them).
struct ComfortEntry: TimelineEntry {
    let date: Date
    let descriptor: ComfortDescriptor
}

extension ComfortEntry {
    /// Representative entry for the gallery, previews, and the redacted placeholder.
    /// "Muggy" is chosen because both the word and a distinct symbol render clearly.
    static let sample = ComfortEntry(date: .now, descriptor: .muggy)
}
