import Foundation
import ThermalComfort

/// A user's override of the comfort word for one temperature/dew-point *band*.
///
/// We persist the raw (temp, dew) reading the user customized at — not the band —
/// and re-derive the band via `classify` on every read. So retuning the comfort
/// thresholds simply reclassifies this sample into whatever band now contains it;
/// there is nothing to migrate. See `ComfortBand`.
public struct Customization: Codable, Equatable, Sendable {
    public let tempF: Double
    public let dewpointF: Double
    public let word: String

    public init(tempF: Double, dewpointF: Double, word: String) {
        self.tempF = tempF
        self.dewpointF = dewpointF
        self.word = word
    }
}

/// Validation for a custom comfort word. The constraints are layout-driven (the
/// word has to fit the watch-face hero and the rectangular complication), not
/// linguistic, so the character set is permissive — anything that renders — and we
/// only reject empty, over-length, or non-printing input rather than restrict to
/// letters.
public enum ComfortWord {
    /// Longest a custom word may be. Sized so it can't overflow the hero label or
    /// the complication; the longest catalog word ("Comfortable") is 11.
    public static let maxLength = 14

    /// Returns a cleaned word ready to store, or `nil` if the input can't be a valid
    /// comfort word. Trims surrounding whitespace, then rejects empty, too-long, or
    /// anything containing control / non-printing characters. Otherwise the text is
    /// stored as typed.
    public static func validate(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength else { return nil }
        let forbidden = CharacterSet.controlCharacters.union(.illegalCharacters)
        guard trimmed.rangeOfCharacter(from: forbidden) == nil else { return nil }
        return trimmed
    }
}

/// Stores the user's per-band comfort-word overrides in the shared App Group so the
/// app and the complication resolve the same word. Modeled on `SnapshotCache`: a
/// small JSON blob in `UserDefaults`, with the defaults instance injectable so
/// tests use an isolated suite.
public struct CustomizationStore {
    private static let key = "customizations"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    public func all() -> [Customization] {
        guard let data = defaults.data(forKey: Self.key) else { return [] }
        return (try? JSONDecoder().decode([Customization].self, from: data)) ?? []
    }

    /// The override whose saved reading falls in the same band as `(tempF, dewpointF)`,
    /// or `nil`. Newest wins if two saved samples share a band — only reachable if a
    /// later threshold change moved two previously-distinct samples together.
    public func customization(forTempF tempF: Double, dewpointF: Double) -> Customization? {
        let band = classify(tempF: tempF, dewpointF: dewpointF).band
        return all().last { classify(tempF: $0.tempF, dewpointF: $0.dewpointF).band == band }
    }

    /// The descriptor to show for these conditions: the user's custom word for this
    /// band if set, otherwise the engine default. Precipitation, which outranks both,
    /// is applied by the caller before this is consulted.
    public func resolvedDescriptor(forTempF tempF: Double, dewpointF: Double) -> ComfortDescriptor {
        if let custom = customization(forTempF: tempF, dewpointF: dewpointF) {
            return ComfortDescriptor(word: custom.word)
        }
        return describe(tempF: tempF, dewpointF: dewpointF)
    }

    /// Saves `word` as the override for the band containing `(tempF, dewpointF)`,
    /// replacing any existing override for that band. `word` is expected to have
    /// passed `ComfortWord.validate`.
    public func setWord(_ word: String, forTempF tempF: Double, dewpointF: Double) {
        write(replacingBandOf: tempF, dewpointF, with: Customization(tempF: tempF, dewpointF: dewpointF, word: word))
    }

    /// Removes the override for the band containing `(tempF, dewpointF)`, if any.
    public func removeCustomization(forTempF tempF: Double, dewpointF: Double) {
        write(replacingBandOf: tempF, dewpointF, with: nil)
    }

    // Drop any existing override sharing the target's band, then append `replacement`
    // (if any) — keeping at most one override per band.
    private func write(replacingBandOf tempF: Double, _ dewpointF: Double, with replacement: Customization?) {
        let band = classify(tempF: tempF, dewpointF: dewpointF).band
        var list = all().filter { classify(tempF: $0.tempF, dewpointF: $0.dewpointF).band != band }
        if let replacement { list.append(replacement) }
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
