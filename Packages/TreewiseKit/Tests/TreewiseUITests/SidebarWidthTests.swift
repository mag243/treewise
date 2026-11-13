import Foundation
import Testing
import TreewiseCore
import TreewiseUI

/// The sidebar's width: its range, the width a window starts at, and where it is kept
/// (ADR 0093).
@Suite struct SidebarWidthTests {
    @Test func startsAtTheIdealBeforeAnyIsChosen() {
        #expect(SidebarWidth.start(restored: nil, lastChosen: nil) == 260)
    }

    @Test func startsANewWindowAtTheLastWidthChosen() {
        #expect(SidebarWidth.start(restored: nil, lastChosen: 300) == 300)
    }

    @Test func startsARestoredWindowAtItsOwnWidth() {
        #expect(SidebarWidth.start(restored: 320, lastChosen: 300) == 320)
    }

    @Test func startsWithinItsRange() {
        #expect(SidebarWidth.start(restored: 500, lastChosen: nil) == 400)
        #expect(SidebarWidth.start(restored: nil, lastChosen: 100) == 160)
    }

    @Test func leavesTheFolderSideItsMinimumInTheNarrowestWindow() {
        #expect(SidebarWidth.narrowestWindow == SidebarWidth.minimum + SidebarWidth.folderMinimum)
    }

    @MainActor @Test func isKeptInTheSettings() {
        let store = MemorySettingsStore()
        #expect(BrowserSettings(store: store).sidebarWidth == nil)
        BrowserSettings(store: store).sidebarWidth = 312
        #expect(BrowserSettings(store: store).sidebarWidth == 312)
    }

    @Test func isKeptWithAWindow() throws {
        var snapshot = WindowSnapshot(
            layout: PaneLayout(panes: [PaneModel(at: "documents")], focused: 0),
            sort: ItemSort(), viewMode: .list)
        snapshot.sidebarWidth = 312
        let decoded = try JSONDecoder().decode(
            WindowSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(decoded.sidebarWidth == 312)
        #expect(decoded.restored { _ in true }?.sidebarWidth == 312)
    }

    @Test func aWindowKeptBeforeHasNoWidth() throws {
        let snapshot = WindowSnapshot(
            layout: PaneLayout(panes: [PaneModel(at: "documents")], focused: 0),
            sort: ItemSort(), viewMode: .list)
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot))
                as? [String: Any])
        json.removeValue(forKey: "sidebarWidth")
        let old = try JSONSerialization.data(withJSONObject: json)
        #expect(try JSONDecoder().decode(WindowSnapshot.self, from: old).sidebarWidth == nil)
    }
}
