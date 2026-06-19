/// A single-word descriptor of how outdoor conditions feel, plus an *icon* to
/// represent it visually.
///
/// Vocabulary (used consistently across code and docs): the **word** and the
/// **icon** are two independent display channels — a complication can show
/// either one alone. The icon has two renditions: a color **emoji** for rich
/// contexts (the full-screen app) and an SF **symbol** for tinted watch-face
/// complications, where emoji render as flat gray and look bad.
///
/// Modeled as a value type with a fixed catalog rather than free strings so the
/// word/icon mapping lives in exactly one place and can't drift as the
/// thresholds in `describe` get retuned.
public struct ComfortDescriptor: Equatable, Hashable, Sendable {
    /// The single-word descriptor, e.g. "Muggy". Shown to the user.
    public let word: String
    /// Color emoji rendition of the icon, for rich contexts (the full-screen app).
    public let emoji: String
    /// SF Symbol rendition of the icon, for complications. Chosen to be visually
    /// distinct across the whole catalog (no two words share a glyph, except the
    /// two "Warm" bands which deliberately match), spreading the temperature axis
    /// across the thermometer family and the modifier across sun/cloud/moisture
    /// glyphs. Still worth a final eyeball on-device, since shapes read differently
    /// when tinted and shrunk to a complication slot.
    public let symbol: String

    public init(word: String, emoji: String, symbol: String) {
        self.word = word
        self.emoji = emoji
        self.symbol = symbol
    }
}

// MARK: - Catalog

// The canonical descriptors. Most map one word to one emoji; the lone exception
// is "Warm", which the spec emits with two different suns depending on the
// temperature band (☀️ in the 75–79°F band, 🌞 in the 80–89°F band). Preserved
// here verbatim as `warm` vs `warmBright` — flagged as a likely spec
// inconsistency to resolve during real-world tuning.
public extension ComfortDescriptor {
    static let bitter      = Self(word: "Bitter",      emoji: "🥶", symbol: "thermometer.snowflake")
    static let raw         = Self(word: "Raw",         emoji: "🌫️", symbol: "cloud.fog.fill")
    static let freezing    = Self(word: "Freezing",    emoji: "❄️", symbol: "snowflake")
    static let crisp       = Self(word: "Crisp",       emoji: "🍃", symbol: "leaf.fill")
    static let cold        = Self(word: "Cold",        emoji: "🧥", symbol: "thermometer.low")
    static let clammy      = Self(word: "Clammy",      emoji: "🌫️", symbol: "humidity.fill")
    static let brisk       = Self(word: "Brisk",       emoji: "💨", symbol: "wind")
    static let comfortable = Self(word: "Comfortable", emoji: "🌤️", symbol: "cloud.sun.fill")
    static let damp        = Self(word: "Damp",        emoji: "💧", symbol: "cloud.drizzle.fill")
    static let pleasant    = Self(word: "Pleasant",    emoji: "☀️", symbol: "sun.min.fill")
    static let sticky      = Self(word: "Sticky",      emoji: "💦", symbol: "drop.fill")
    static let muggy       = Self(word: "Muggy",       emoji: "😓", symbol: "cloud.fill")
    static let balmy       = Self(word: "Balmy",       emoji: "🌞", symbol: "sun.haze.fill")
    static let warm        = Self(word: "Warm",        emoji: "☀️", symbol: "sun.max.fill")
    static let warmBright  = Self(word: "Warm",        emoji: "🌞", symbol: "sun.max.fill")
    static let oppressive  = Self(word: "Oppressive",  emoji: "😰", symbol: "thermometer.high")
    static let hot         = Self(word: "Hot",         emoji: "🌡️", symbol: "thermometer.medium")
    static let sweltering  = Self(word: "Sweltering",  emoji: "🔥", symbol: "flame.fill")
    static let miserable   = Self(word: "Miserable",   emoji: "😵", symbol: "thermometer.sun.fill")
    static let dryHeat     = Self(word: "Dry Heat",    emoji: "🌵", symbol: "sun.dust.fill")
    static let dangerous   = Self(word: "Dangerous",   emoji: "🥵", symbol: "exclamationmark.triangle.fill")
    static let scorching   = Self(word: "Scorching",   emoji: "🏜️", symbol: "sun.max.trianglebadge.exclamationmark")
    static let deadly      = Self(word: "Deadly",      emoji: "☠️", symbol: "exclamationmark.octagon.fill")
}

extension ComfortDescriptor {
    /// Every canonical descriptor, in cold-to-hot order — for catalog-wide checks
    /// (e.g. the symbol-distinctness test) and any future gallery iteration.
    static let all: [ComfortDescriptor] = [
        .bitter, .raw, .freezing, .crisp, .cold, .clammy, .brisk, .comfortable,
        .damp, .pleasant, .sticky, .muggy, .balmy, .warm, .warmBright, .oppressive,
        .hot, .sweltering, .miserable, .dryHeat, .dangerous, .scorching, .deadly,
    ]
}
