import SwiftUI
import WidgetKit

/// Entry point for the widget extension. Two complication kinds: the comfort (or
/// precipitation) word for the rectangular/inline slots, and the bare dew point
/// number for the round circular/corner slots.
@main
struct DewPointComplications: WidgetBundle {
    var body: some Widget {
        WordComplication()
        DewpointComplication()
    }
}
