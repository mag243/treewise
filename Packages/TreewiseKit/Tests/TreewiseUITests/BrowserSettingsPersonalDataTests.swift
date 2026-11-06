import Testing
import TreewiseUI

/// What Approve All does with names that hold personal data (ADR 0060).
@MainActor
@Suite struct BrowserSettingsPersonalDataTests {
    @Test func leavesThemOutOfApproveAllAtFirst() {
        #expect(
            BrowserSettings(store: MemorySettingsStore()).personalDataInNames
                == .leaveOutOfApproveAll)
    }

    @Test func keepsTheUsersChoice() {
        let store = MemorySettingsStore()
        BrowserSettings(store: store).personalDataInNames = .onlyWarn
        #expect(BrowserSettings(store: store).personalDataInNames == .onlyWarn)
    }
}
