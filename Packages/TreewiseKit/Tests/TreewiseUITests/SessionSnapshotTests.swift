import Foundation
import Testing
import TreewiseCore
import TreewiseUI

/// What a restart brings back of the windows and their tabs (ADR 0038).
@Suite struct SessionSnapshotTests {
    private func tab(_ folder: FileItem.ID, view: ViewMode = .list) -> WindowSnapshot {
        WindowSnapshot(layout: PaneLayout(at: folder), sort: ItemSort(), viewMode: view)
    }

    private func session() -> SessionSnapshot {
        SessionSnapshot(groups: [
            .init(tabs: [tab("documents"), tab("projects", view: .icons)], selectedTab: 1),
            .init(tabs: [tab("downloads")], selectedTab: 0),
        ])
    }

    private func folders(_ groups: [RestoredGroup]) -> [[FileItem.ID]] {
        groups.map { $0.tabs.map(\.layout.focusedPane.activeTab.folder) }
    }

    @Test func restoresEveryGroupWithItsTabsInOrder() throws {
        let decoded = try JSONDecoder().decode(
            SessionSnapshot.self, from: JSONEncoder().encode(session()))
        let groups = decoded.restored { _ in true }
        #expect(folders(groups) == [["documents", "projects"], ["downloads"]])
        #expect(groups.map(\.selectedTab) == [1, 0])
        #expect(groups[0].tabs[1].viewMode == .icons)
    }

    @Test func keepsTheSelectedTabWhenATabBeforeItIsLeftOut() {
        let groups = session().restored { $0 != "documents" }
        #expect(folders(groups) == [["projects"], ["downloads"]])
        #expect(groups[0].selectedTab == 0)
    }

    @Test func selectsTheFirstTabWhenTheSelectedOneIsLeftOut() {
        let groups = session().restored { $0 != "projects" }
        #expect(folders(groups) == [["documents"], ["downloads"]])
        #expect(groups[0].selectedTab == 0)
    }

    @Test func leavesOutAGroupWithoutTabs() {
        let groups = session().restored { $0 != "downloads" }
        #expect(folders(groups) == [["documents", "projects"]])
    }

    @Test func restoresNothingWhenNoFolderCanBeShown() {
        #expect(session().restored { _ in false }.isEmpty)
    }

    @Test func makesEveryTabOfEveryPaneATabOfItsOwn() throws {
        var left = PaneModel(at: "documents")
        left.openTab(at: "projects")
        let split = WindowSnapshot(
            layout: PaneLayout(panes: [left, PaneModel(at: "downloads")], focused: 1),
            sort: ItemSort(column: .size, ascending: false), viewMode: .icons)
        let session = SessionSnapshot(groups: [
            .init(tabs: [tab("music"), split], selectedTab: 1)
        ])
        let group = try #require(session.restored { _ in true }.first).oneFolderPerTab()

        #expect(folders([group]) == [["music", "documents", "projects", "downloads"]])
        #expect(group.tabs.allSatisfy { $0.layout.panes.count == 1 })
        #expect(group.selectedTab == 3, "the focused pane's tab of the selected window")
        #expect(group.tabs[1].viewMode == .icons, "each keeps its window's view")
        #expect(group.tabs[1].sort == ItemSort(column: .size, ascending: false))
    }

    @Test func aWindowOfOneReleaseBackIsASessionOfOneGroup() {
        let window = tab("projects")
        #expect(
            SessionSnapshot(window: window)
                == SessionSnapshot(groups: [.init(tabs: [window], selectedTab: 0)]))
    }
}
