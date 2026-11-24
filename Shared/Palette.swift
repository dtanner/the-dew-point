import SwiftUI

/// Colors shared by the iPhone screens and widgets, matching the app icon's deep
/// navy. (The watch draws on black and doesn't use these.)
enum Palette {
    static let background = Color(red: 0.024, green: 0.078, blue: 0.114)
    static let surface = Color(red: 0.047, green: 0.137, blue: 0.192)
    /// The app's AccentColor asset as a value, for the widget extension, which has
    /// no asset catalog of its own. Keep in step with
    /// Phone/Assets.xcassets/AccentColor.colorset.
    static let accent = Color(red: 0.361, green: 0.784, blue: 0.894)
}
