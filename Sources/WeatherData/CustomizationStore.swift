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
    /// the complication; the longest catalog words ("Freezing", "Pleasant",
    /// "Stifling", "Dry Heat") are 8.
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

/// The slice of `NSUbiquitousKeyValueStore` that customization sync uses, so tests
/// can substitute an in-memory store.
public protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: KeyValueStore {}

/// Stores the user's per-band comfort-word overrides in the shared App Group so the
/// app and the complication resolve the same word. Modeled on `SnapshotCache`: a
/// small JSON blob in `UserDefaults`, with the defaults instance injectable so
/// tests use an isolated suite.
///
/// With a `cloud` store (the watch and iPhone apps pass iCloud key-value storage),
/// every write is mirrored there and `syncFromCloud()` pulls other devices' changes
/// into the local copy. The complication reads the local copy only, so it never
/// needs the iCloud entitlement; the app keeps that copy current.
public struct CustomizationStore {
    private static let key = "customizations"
    /// Set once this device's list has been reconciled with the cloud copy. Before
    /// that, the two are merged rather than one replacing the other.
    private static let cloudSyncedKey = "customizationsCloudSynced"

    private let defaults: UserDefaults
    private let cloud: (any KeyValueStore)?

    public init(defaults: UserDefaults = AppGroup.defaults, cloud: (any KeyValueStore)? = nil) {
        self.defaults = defaults
        self.cloud = cloud
    }

    /// The store the watch and iPhone apps use: the shared App Group, mirrored to
    /// iCloud key-value storage so custom words follow the user across devices.
    public static var synced: CustomizationStore {
        CustomizationStore(cloud: NSUbiquitousKeyValueStore.default)
    }

    public func all() -> [Customization] {
        Self.decode(defaults.data(forKey: Self.key)) ?? []
    }

    /// The override whose saved reading falls in the same band as `(tempF, dewpointF)`,
    /// or `nil`. Newest wins if two saved samples share a band — only reachable if a
    /// later threshold change moved two previously-distinct samples together.
    public func customization(forTempF tempF: Double, dewpointF: Double) -> Customization? {
        customization(for: classify(tempF: tempF, dewpointF: dewpointF).band)
    }

    /// The override for `band`, or `nil`. Newest wins, as above.
    public func customization(for band: ComfortBand) -> Customization? {
        all().last { $0.band == band }
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

    /// Reconciles the local list with the cloud copy and reports whether the local
    /// list changed (so the caller can re-render and reload widgets).
    ///
    /// - Cloud empty: this device is the source; push its words up, if it has any.
    ///   An empty device pushes nothing, so a fresh install whose cloud copy hasn't
    ///   downloaded yet can't wipe the words another device already saved.
    /// - First sync with a cloud copy: merge, keeping the cloud's word where both
    ///   have one for a band, so an existing watch user's words survive installing
    ///   the iPhone app (and vice versa).
    /// - After that: the cloud copy replaces the local one, so deletions propagate.
    ///
    /// Pass `initialSync: true` when iCloud reports that its first download replaced
    /// values this device had set (`NSUbiquitousKeyValueStoreInitialSyncChange`).
    /// A fresh install that saved a word before the download pushed a list without
    /// the other devices' words; merging keeps both sides.
    @discardableResult
    public func syncFromCloud(initialSync: Bool = false) -> Bool {
        guard let cloud else { return false }
        let local = all()
        guard let cloudList = Self.decode(cloud.data(forKey: Self.key)) else {
            if !local.isEmpty {
                cloud.set(Self.encode(local), forKey: Self.key)
                defaults.set(true, forKey: Self.cloudSyncedKey)
            }
            return false
        }
        var merged = cloudList
        if initialSync || !defaults.bool(forKey: Self.cloudSyncedKey) {
            let cloudBands = Set(cloudList.map(\.band))
            merged += local.filter { !cloudBands.contains($0.band) }
            defaults.set(true, forKey: Self.cloudSyncedKey)
            if merged != cloudList {
                cloud.set(Self.encode(merged), forKey: Self.key)
            }
        }
        guard merged != local else { return false }
        defaults.set(Self.encode(merged), forKey: Self.key)
        return true
    }

    // Drop any existing override sharing the target's band, then append `replacement`
    // (if any) — keeping at most one override per band.
    private func write(replacingBandOf tempF: Double, _ dewpointF: Double, with replacement: Customization?) {
        // A device that hasn't reconciled yet would otherwise push a list missing
        // the other devices' words, overwriting them in the cloud. (If the cloud
        // copy hasn't downloaded to this device yet there's nothing to merge here;
        // the download then arrives as an initial-sync change, which merges.)
        if cloud != nil, !defaults.bool(forKey: Self.cloudSyncedKey) {
            syncFromCloud()
        }
        let band = classify(tempF: tempF, dewpointF: dewpointF).band
        var list = all().filter { $0.band != band }
        if let replacement { list.append(replacement) }
        guard let data = Self.encode(list) else { return }
        defaults.set(data, forKey: Self.key)
        cloud?.set(data, forKey: Self.key)
        if cloud != nil {
            defaults.set(true, forKey: Self.cloudSyncedKey)
        }
    }

    private static func decode(_ data: Data?) -> [Customization]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([Customization].self, from: data)
    }

    private static func encode(_ list: [Customization]) -> Data? {
        try? JSONEncoder().encode(list)
    }
}

private extension Customization {
    var band: ComfortBand { classify(tempF: tempF, dewpointF: dewpointF).band }
}
