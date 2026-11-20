import Testing
import TreewiseCore
import TreewiseUI

/// The settings' part in syncing (ADR 0144): the switch, on by default, and the saved
/// patterns' changes told to the sync, but not those it brings.
@MainActor
@Suite struct BrowserSettingsSyncTests {
    @Test func syncingIsOnByDefaultAndKeptOff() {
        let store = MemorySettingsStore()
        let settings = BrowserSettings(store: store)
        #expect(settings.syncsSettings)
        settings.syncsSettings = false
        #expect(!BrowserSettings(store: store).syncsSettings)
    }

    @Test func aChangeToTheSavedPatternsIsToldWithWhatItWas() {
        let settings = BrowserSettings(store: MemorySettingsStore())
        var told: [(SavedPatterns, SavedPatterns)] = []
        settings.savedPatternsChanged = { told.append(($0, $1)) }
        let before = settings.savedPatterns
        _ = settings.savedPatterns.save(name: "Tax", text: "Tax - {text}")
        #expect(told.count == 1)
        #expect(told.first?.0 == before)
        #expect(told.first?.1 == settings.savedPatterns)
    }

    @Test func patternsTakenOverFromAnotherDeviceAreNotTold() {
        let store = MemorySettingsStore()
        let settings = BrowserSettings(store: store)
        var told = 0
        settings.savedPatternsChanged = { _, _ in told += 1 }
        var theirs = settings.savedPatterns
        _ = theirs.save(name: "Tax", text: "Tax - {text}")

        settings.takeOver(theirs)

        #expect(told == 0)
        #expect(BrowserSettings(store: store).savedPatterns == theirs, "and they are kept")
    }
}
