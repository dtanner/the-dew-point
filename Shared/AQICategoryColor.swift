import SwiftUI
import WeatherData

extension AQICategory {
    /// The EPA's severity color for the category, tuned for the black
    /// background both renderings sit on (the watch face and the app screen):
    /// the system green/yellow/orange/red/purple are close matches with better
    /// legibility than the EPA's exact swatches, and the EPA's hazardous
    /// maroon (#7E0023) is nearly invisible on black, so it's lightened while
    /// keeping the hue. Compiled into both the app and the complication so the
    /// two renderings of the same reading can't drift apart. On the watch
    /// face, only full-color faces show these — tinted and vibrant faces
    /// flatten every complication to the face's own palette.
    var color: Color {
        switch self {
        case .good: .green
        case .moderate: .yellow
        case .unhealthyForSensitiveGroups: .orange
        case .unhealthy: .red
        case .veryUnhealthy: .purple
        case .hazardous: Color(red: 0.86, green: 0.19, blue: 0.36)
        }
    }
}
