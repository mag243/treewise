import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Volumes that come and go, This Mac and leaving a volume to eject it (ADR 0044).
@MainActor
@Suite struct BrowserStateVolumeTests {
    /// Two volumes in This Mac, each with a folder.
    private static let tree = InMemoryFileSystem([
        FileItem(id: "hd", name: "Macintosh HD", kind: .volume, parentID: .computer, volume: "hd"),
        FileItem(id: "work", name: "Work", kind: .folder, parentID: "hd", volume: "hd"),
        FileItem(id: "usb", name: "T7", kind: .volume, parentID: .computer, volume: "usb"),
        FileItem(id: "photos", name: "Photos", kind: .folder, parentID: "usb", volume: "usb"),
    ])

    @Test func thisMacListsTheVolumes() async {
        let browser = await makeBrowser(fileSystem: Self.tree, at: .computer)
        #expect(browser.focusedNames == ["Macintosh HD", "T7"])
    }

    @Test func watchesThisMacForVolumes() async {
        let watcher = ManualFolderWatcher()
        _ = await makeBrowser(fileSystem: Self.tree, watcher: watcher, at: "work")
        #expect(await eventually { watcher.watchedFolders.contains(.computer) })
    }

    @Test func dropsAVolumeThatLeftFromTheSidebar() async {
        let fileSystem = ChangingFileSystem(Self.tree)
        let watcher = ManualFolderWatcher()
        let browser = await makeBrowser(fileSystem: fileSystem, watcher: watcher, at: "work")
        #expect(await eventually { watcher.watchedFolders.contains(.computer) })

        fileSystem.remove("usb")
        watcher.change(.computer)

        #expect(await eventually { browser.locations.map(\.id) == ["hd"] })
    }

    @Test func movesATabOnAVolumeThatLeftToThisMac() async {
        let fileSystem = ChangingFileSystem(Self.tree)
        let watcher = ManualFolderWatcher()
        let browser = await makeBrowser(fileSystem: fileSystem, watcher: watcher, at: "photos")
        #expect(await eventually { watcher.watchedFolders.contains("photos") })

        fileSystem.remove("usb")
        watcher.change("photos")

        #expect(await eventually { browser.focusedFolder == .computer })
        #expect(await eventually { browser.focusedNames == ["Macintosh HD"] })
    }

    @Test func leavingAVolumeMovesEveryTabOnItToThisMac() async {
        let browser = await makeBrowser(fileSystem: Self.tree, at: "photos")
        await browser.openTab(pane: 0, at: "usb")
        await browser.openTab(pane: 0, at: "work")

        await browser.leave(volume: "usb")

        let folders = browser.layout.focusedPane.tabs.map(\.folder)
        #expect(folders == [.computer, .computer, "work"])
    }

    @Test func thisMacTakesNoNewFolder() async {
        let browser = await makeBrowser(fileSystem: ChangingFileSystem(Self.tree), at: .computer)
        #expect(!browser.canAddItems)
        #expect(await browser.newFolder(undoManager: nil) == nil)
        #expect(browser.focusedNames == ["Macintosh HD", "T7"])
    }

    @Test func aFolderTakesNewItems() async {
        let browser = await makeBrowser(fileSystem: Self.tree, at: "work")
        #expect(browser.canAddItems)
    }
}
