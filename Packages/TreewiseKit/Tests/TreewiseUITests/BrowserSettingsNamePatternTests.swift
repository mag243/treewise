import Testing
import TreewiseCore
import TreewiseUI

/// The user's saved patterns, one of them the default for folders without one
/// (ADR 0057, ADR 0068).
@MainActor
@Suite struct BrowserSettingsNamePatternTests {
    @Test func startsWithTheExamplesAndADateAndText() {
        let settings = BrowserSettings(store: MemorySettingsStore())
        #expect(settings.savedPatterns.patterns.count == 4)
        #expect(settings.defaultNamePattern == "{date:yyyy.MM.dd} {text}")
    }

    @Test func keepsTheUsersList() {
        let store = MemorySettingsStore()
        let settings = BrowserSettings(store: store)
        let id = try? settings.savedPatterns.save(name: "Tax", text: "Tax - {text}").get()
        settings.savedPatterns.makeDefault(id ?? "")
        let again = BrowserSettings(store: store)
        #expect(again.savedPatterns == settings.savedPatterns)
        #expect(again.defaultNamePattern == "Tax - {text}")
    }

    @Test func aDefaultStoredBeforeTheListBecomesItsDefault() {
        let store = MemorySettingsStore()
        store.setSetting("{text} - {seq}", for: "defaultNamePattern")
        #expect(BrowserSettings(store: store).defaultNamePattern == "{text} - {seq}")
    }
}
