import Foundation
import Testing
import ThermalComfort
@testable import WeatherData

/// Custom words follow the user across devices through a shared key-value store:
/// first contact merges, later changes (deletes included) replace, and an empty
/// device never wipes another device's words.
struct CustomizationSyncTests {

    /// In-memory stand-in for iCloud key-value storage, shared between "devices".
    final class FakeCloud: KeyValueStore {
        var values: [String: Data] = [:]
        func data(forKey key: String) -> Data? { values[key] }
        func set(_ data: Data?, forKey key: String) { values[key] = data }
        func synchronize() -> Bool { true }
    }

    // A device's own isolated local storage.
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "CustomizationSyncTests.\(UUID().uuidString)")!
    }

    // One device talking to the shared cloud.
    private func makeDevice(_ cloud: FakeCloud, defaults: UserDefaults? = nil) -> CustomizationStore {
        CustomizationStore(defaults: defaults ?? makeDefaults(), cloud: cloud)
    }

    @Test func writeOnOneDeviceReachesAnother() {
        let cloud = FakeCloud()
        let watch = makeDevice(cloud)
        let phone = makeDevice(cloud)
        watch.setWord("Soup", forTempF: 70, dewpointF: 64)
        #expect(phone.syncFromCloud())
        #expect(phone.resolvedDescriptor(forTempF: 70, dewpointF: 64) == ComfortDescriptor(word: "Soup"))
    }

    @Test func existingWordsSurviveFirstSyncWithAnotherDevice() {
        let cloud = FakeCloud()
        let watchDefaults = makeDefaults()
        // The watch customized before sync existed (no cloud store at the time).
        CustomizationStore(defaults: watchDefaults).setWord("Soup", forTempF: 70, dewpointF: 64) // Mild/Muggy
        let watch = makeDevice(cloud, defaults: watchDefaults)
        let phone = makeDevice(cloud)
        phone.setWord("Brrr", forTempF: 55, dewpointF: 30)      // Cool/Crisp, reaches cloud first
        #expect(watch.syncFromCloud())
        #expect(Set(watch.all().map(\.word)) == ["Soup", "Brrr"])
        // The merge went back up, so the phone picks up the watch's older word too.
        #expect(phone.syncFromCloud())
        #expect(Set(phone.all().map(\.word)) == ["Soup", "Brrr"])
    }

    @Test func cloudWinsWhenBothHaveTheSameBandOnFirstSync() {
        let cloud = FakeCloud()
        let watchDefaults = makeDefaults()
        CustomizationStore(defaults: watchDefaults).setWord("Soup", forTempF: 70, dewpointF: 64)
        let watch = makeDevice(cloud, defaults: watchDefaults)
        let phone = makeDevice(cloud)
        phone.setWord("Stew", forTempF: 72, dewpointF: 65) // same band
        watch.syncFromCloud()
        #expect(watch.resolvedDescriptor(forTempF: 70, dewpointF: 64) == ComfortDescriptor(word: "Stew"))
        #expect(watch.all().count == 1)
    }

    @Test func deletesPropagateAfterFirstSync() {
        let cloud = FakeCloud()
        let watch = makeDevice(cloud)
        let phone = makeDevice(cloud)
        watch.setWord("Soup", forTempF: 70, dewpointF: 64)
        phone.syncFromCloud()
        phone.removeCustomization(forTempF: 70, dewpointF: 64)
        #expect(watch.syncFromCloud())
        #expect(watch.all().isEmpty)
    }

    @Test func emptyDeviceDoesNotWipeTheCloud() {
        let cloud = FakeCloud()
        let fresh = makeDevice(cloud)
        #expect(!fresh.syncFromCloud())
        #expect(cloud.values.isEmpty)
    }

    @Test func deviceWithWordsSeedsAnEmptyCloud() {
        let cloud = FakeCloud()
        let watchDefaults = makeDefaults()
        CustomizationStore(defaults: watchDefaults).setWord("Soup", forTempF: 70, dewpointF: 64)
        let watch = makeDevice(cloud, defaults: watchDefaults)
        #expect(!watch.syncFromCloud()) // local unchanged; it was the source
        let phone = makeDevice(cloud)
        #expect(phone.syncFromCloud())
        #expect(phone.all().map(\.word) == ["Soup"])
    }

    @Test func storeWithoutCloudNeverSyncs() {
        let store = CustomizationStore(defaults: makeDefaults())
        #expect(!store.syncFromCloud())
    }

}
