/// A single-word descriptor of how outdoor conditions feel, e.g. "Muggy".
///
/// Modeled as a value type with a fixed catalog rather than free strings so the
/// vocabulary lives in exactly one place and can't drift as the thresholds in
/// `describe` get retuned. `Codable` so it can ride inside the cached
/// `WeatherSnapshot` as the precipitation override.
public struct ComfortDescriptor: Equatable, Hashable, Sendable, Codable {
    /// The single-word descriptor, e.g. "Muggy". Shown to the user.
    public let word: String

    public init(word: String) {
        self.word = word
    }
}

// MARK: - Catalog

// The canonical descriptors, in cold-to-hot order.
public extension ComfortDescriptor {
    static let bitter      = Self(word: "Bitter")
    static let raw         = Self(word: "Raw")
    static let freezing    = Self(word: "Freezing")
    static let crisp       = Self(word: "Crisp")
    static let cold        = Self(word: "Cold")
    static let clammy      = Self(word: "Clammy")
    static let brisk       = Self(word: "Brisk")
    static let comfy       = Self(word: "Comfy")
    static let damp        = Self(word: "Damp")
    static let pleasant    = Self(word: "Pleasant")
    static let sticky      = Self(word: "Sticky")
    static let muggy       = Self(word: "Muggy")
    static let balmy       = Self(word: "Balmy")
    static let warm        = Self(word: "Warm")
    static let stifling    = Self(word: "Stifling")
    static let hot         = Self(word: "Hot")
    static let steamy      = Self(word: "Steamy")
    static let brutal      = Self(word: "Brutal")
    static let dryHeat     = Self(word: "Dry Heat")
    static let danger      = Self(word: "Danger")
    static let searing     = Self(word: "Searing")
    static let deadly      = Self(word: "Deadly")
}

public extension ComfortDescriptor {
    /// Every canonical descriptor, in cold-to-hot order — for catalog-wide checks
    /// (e.g. the complication sizing its font to the widest word) and any future
    /// gallery iteration.
    static let all: [ComfortDescriptor] = [
        .bitter, .raw, .freezing, .crisp, .cold, .clammy, .brisk, .comfy,
        .damp, .pleasant, .sticky, .muggy, .balmy, .warm, .stifling,
        .hot, .steamy, .brutal, .dryHeat, .danger, .searing, .deadly,
    ]
}
