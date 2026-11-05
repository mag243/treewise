import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// The window's settings and where they are kept (ADR 0023).
@MainActor
@Suite struct BrowserSettingsTests {
    @Test func startsWithTheDefaults() {
        let settings = BrowserSettings(store: MemorySettingsStore())
        #expect(!settings.showsHiddenFiles)
        #expect(settings.showsExtensions)
        #expect(settings.rowDensity == .medium)
        #expect(settings.startFolder == nil)
        #expect(settings.doubleClickOpensIn == .samePane)
        #expect(!settings.showsDetails)
        #expect(settings.terminalApp == nil)
    }

    @Test func keepsTheTerminalApp() {
        let store = MemorySettingsStore()
        BrowserSettings(store: store).terminalApp = "com.example.terminal"
        #expect(BrowserSettings(store: store).terminalApp == "com.example.terminal")
    }

    @Test func keepsChangesInItsStore() {
        let store = MemorySettingsStore()
        let settings = BrowserSettings(store: store)
        settings.showsHiddenFiles = true
        settings.showsExtensions = false
        settings.rowDensity = .large
        settings.startFolder = "projects"
        settings.doubleClickOpensIn = .otherPane
        settings.showsDetails = true

        let again = BrowserSettings(store: store)
        #expect(again.showsHiddenFiles)
        #expect(!again.showsExtensions)
        #expect(again.rowDensity == .large)
        #expect(again.startFolder == "projects")
        #expect(again.doubleClickOpensIn == .otherPane)
        #expect(again.showsDetails)
    }

    @Test func startsAtTheChosenFolderWhenItCanBeShown() {
        let settings = BrowserSettings(store: MemorySettingsStore())
        settings.startFolder = "projects"
        #expect(settings.startFolder(home: "home", lookUp: { Fixture.standard[$0] }) == "projects")
    }

    @Test(arguments: ["gone", "doc2"])
    func startsAtHomeWhenTheChosenFolderIsGoneOrAFile(_ chosen: FileItem.ID) {
        let settings = BrowserSettings(store: MemorySettingsStore())
        settings.startFolder = chosen
        #expect(settings.startFolder(home: "home", lookUp: { Fixture.standard[$0] }) == "home")
    }

    private func window(_ folder: FileItem.ID) -> WindowSnapshot {
        WindowSnapshot(layout: PaneLayout(at: folder), sort: ItemSort(), viewMode: .list)
    }

    @Test func keepsTheLastSession() {
        let store = MemorySettingsStore()
        let session = SessionSnapshot(groups: [
            .init(tabs: [window("projects"), window("documents")], selectedTab: 1)
        ])
        BrowserSettings(store: store).lastSession = session
        #expect(BrowserSettings(store: store).lastSession == session)
    }

    @Test func keepsTheSessionBeforeOneWithoutWindows() {
        let store = MemorySettingsStore()
        let session = SessionSnapshot(window: window("projects"))
        let settings = BrowserSettings(store: store)
        settings.lastSession = session
        settings.lastSession = SessionSnapshot(groups: [])
        #expect(BrowserSettings(store: store).lastSession == session)
    }

    @Test func readsTheWindowOfOneReleaseBackAsASession() throws {
        let store = MemorySettingsStore()
        let json = try JSONEncoder().encode(window("projects"))
        store.setSetting(String(data: json, encoding: .utf8), for: "lastWindow")
        #expect(
            BrowserSettings(store: store).lastSession
                == SessionSnapshot(window: window("projects")))
    }
}
