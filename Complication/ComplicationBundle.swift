import SwiftUI
import WidgetKit

/// Entry point for the widget extension. A single complication kind that shows the
/// comfort (or precipitation) word, placed in the rectangular or inline slot of a
/// face.
@main
struct DewPointComplications: WidgetBundle {
    var body: some Widget {
        WordComplication()
    }
}
