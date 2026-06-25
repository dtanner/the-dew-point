import Foundation
import Testing
import ThermalComfort
@testable import WeatherData

/// The store's contract: a custom word applies to the whole band it was saved in,
/// stays out of other bands, and round-trips through shared storage.
struct CustomizationStoreTests {

    // A throwaway, isolated defaults suite so tests never touch real storage.
    private func makeStore() -> CustomizationStore {
        let suite = "CustomizationStoreTests.\(UUID().uuidString)"
        return CustomizationStore(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func resolvesDefaultWhenNoCustomization() {
        let store = makeStore()
        #expect(store.resolvedDescriptor(forTempF: 70, dewpointF: 64) == describe(tempF: 70, dewpointF: 64))
    }

    @Test func customWordAppliesAcrossTheWholeBandOnly() {
        let store = makeStore()
        store.setWord("Soup", forTempF: 70, dewpointF: 64)
        // A different reading in the same Mild/Muggy band gets the custom word...
        #expect(store.resolvedDescriptor(forTempF: 73, dewpointF: 66) == ComfortDescriptor(word: "Soup"))
        // ...while a Muggy reading in a different temperature band keeps the default.
        #expect(store.resolvedDescriptor(forTempF: 77, dewpointF: 65) == describe(tempF: 77, dewpointF: 65))
    }

    @Test func setWordReplacesExistingForSameBand() {
        let store = makeStore()
        store.setWord("Soup", forTempF: 70, dewpointF: 64)
        store.setWord("Stew", forTempF: 72, dewpointF: 65) // same band, different reading
        #expect(store.all().count == 1)
        #expect(store.resolvedDescriptor(forTempF: 70, dewpointF: 64) == ComfortDescriptor(word: "Stew"))
    }

    @Test func removeRevertsToDefault() {
        let store = makeStore()
        store.setWord("Soup", forTempF: 70, dewpointF: 64)
        store.removeCustomization(forTempF: 71, dewpointF: 63) // same band, different reading
        #expect(store.customization(forTempF: 70, dewpointF: 64) == nil)
        #expect(store.resolvedDescriptor(forTempF: 70, dewpointF: 64) == describe(tempF: 70, dewpointF: 64))
    }

    @Test func independentBandsCoexist() {
        let store = makeStore()
        store.setWord("Soup", forTempF: 70, dewpointF: 64) // Mild/Muggy
        store.setWord("Brrr", forTempF: 55, dewpointF: 30) // Cool/Crisp
        #expect(Set(store.all().map(\.word)) == ["Soup", "Brrr"])
        #expect(store.resolvedDescriptor(forTempF: 70, dewpointF: 64) == ComfortDescriptor(word: "Soup"))
        #expect(store.resolvedDescriptor(forTempF: 55, dewpointF: 30) == ComfortDescriptor(word: "Brrr"))
    }
}

/// Word validation is layout-driven: cap the length, reject non-printing input, but
/// otherwise accept whatever the user types.
struct ComfortWordTests {

    @Test func acceptsAReasonableWord() {
        #expect(ComfortWord.validate("Soup") == "Soup")
        #expect(ComfortWord.validate("Dry Heat") == "Dry Heat")
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(ComfortWord.validate("  Soup  ") == "Soup")
    }

    @Test func rejectsEmptyAndWhitespaceOnly() {
        #expect(ComfortWord.validate("") == nil)
        #expect(ComfortWord.validate("   ") == nil)
    }

    @Test func enforcesTheLengthCap() {
        #expect(ComfortWord.validate(String(repeating: "a", count: ComfortWord.maxLength)) != nil)
        #expect(ComfortWord.validate(String(repeating: "a", count: ComfortWord.maxLength + 1)) == nil)
    }

    @Test func rejectsControlCharacters() {
        #expect(ComfortWord.validate("So\nup") == nil)
    }
}
