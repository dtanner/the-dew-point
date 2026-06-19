import SwiftUI
import WidgetKit

/// Entry point for the widget extension. Two fixed complication kinds — one shows
/// the word, one shows the icon — so each face slot is configured simply by picking
/// which to place (this is the most reliable path in the iPhone Watch app, which
/// has known bugs editing a single widget's per-slot configuration).
@main
struct DewPointComplications: WidgetBundle {
    var body: some Widget {
        WordComplication()
        IconComplication()
    }
}
