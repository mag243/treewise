import Foundation
import Testing
import TreewiseCore
import TreewiseUI

/// What a restart brings back of a window (ADR 0024).
@Suite struct WindowSnapshotTests {
    private func splitLayout() -> PaneLayout {
        var left = PaneModel(at: "documents")
        left.openTab(at: "projects")
        return PaneLayout(panes: [left, PaneModel(at: "downloads")], focused: 1)
    }

    @Test func restoresThePanesTabsSortOrderAndView() throws {
        let snapshot = WindowSnapshot(
            layout: splitLayout(), sort: ItemSort(column: .size, ascending: false),
            viewMode: .icons)
        let decoded = try JSONDecoder().decode(
            WindowSnapshot.self, from: JSONEncoder().encode(snapshot))

        let window = try #require(decoded.restored { _ in true })
        #expect(
            window.layout.panes.map { $0.tabs.map(\.folder) } == [
                ["documents", "projects"], ["downloads"],
            ])
        #expect(window.layout.panes[0].activeTab.folder == "projects")
        #expect(window.layout.focusedPaneIndex == 1)
        #expect(window.sort == ItemSort(column: .size, ascending: false))
        #expect(window.viewMode == .icons)
    }

    @Test func leavesOutFoldersThatCannotBeShown() throws {
        let snapshot = WindowSnapshot(layout: splitLayout(), sort: ItemSort(), viewMode: .list)
        let layout = try #require(snapshot.restored { $0 != "projects" }).layout
        #expect(layout.panes[0].tabs.map(\.folder) == ["documents"])
        #expect(layout.panes[0].activeTab.folder == "documents")
    }

    @Test func leavesOutAPaneWithoutTabsAndFocusesTheFirst() throws {
        let snapshot = WindowSnapshot(layout: splitLayout(), sort: ItemSort(), viewMode: .list)
        let layout = try #require(snapshot.restored { $0 != "downloads" }).layout
        #expect(!layout.isSplit)
        #expect(layout.focusedPaneIndex == 0)
    }

    @Test func restoresNothingWhenNoFolderCanBeShown() {
        let snapshot = WindowSnapshot(layout: splitLayout(), sort: ItemSort(), viewMode: .list)
        #expect(snapshot.restored { _ in false } == nil)
    }

    @Test func showsTheListForASnapshotWithoutAView() throws {
        let json =
            #"{"panes":[{"folders":["documents"],"activeTab":0}],"focusedPane":0,"sortColumn":"name","ascending":true}"#
        let snapshot = try JSONDecoder().decode(WindowSnapshot.self, from: Data(json.utf8))
        #expect(snapshot.restored { _ in true }?.viewMode == .list)
    }
}
