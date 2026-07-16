import SwiftUI
import WidgetKit

/// Entry point for the widget extension. Three complication kinds: the comfort
/// (or precipitation) word for the rectangular/inline slots, the bare dew point
/// number for the round circular/corner slots, and the air quality index for
/// both kinds of slot.
@main
struct DewPointComplications: WidgetBundle {
    var body: some Widget {
        WordComplication()
        DewpointComplication()
        AQIComplication()
    }
}
