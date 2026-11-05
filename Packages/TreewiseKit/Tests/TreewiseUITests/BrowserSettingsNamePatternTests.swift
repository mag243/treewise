import Testing
import TreewiseUI

/// The user's own pattern for folders without one (ADR 0057).
@MainActor
@Suite struct BrowserSettingsNamePatternTests {
    @Test func startsWithADateAndText() {
        #expect(
            BrowserSettings(store: MemorySettingsStore()).defaultNamePattern
                == "{date:yyyy.MM.dd} {text}")
    }

    @Test func keepsTheUsersPattern() {
        let store = MemorySettingsStore()
        BrowserSettings(store: store).defaultNamePattern = "{text} {number}"
        #expect(BrowserSettings(store: store).defaultNamePattern == "{text} {number}")
    }
}
