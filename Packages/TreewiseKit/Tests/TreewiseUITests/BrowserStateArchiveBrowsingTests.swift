import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Going into an archive from the window, and what can be done there (ADR 0076).
@MainActor
@Suite struct BrowserStateArchiveBrowsingTests {
    private static let archive: FileItem.ID = "/docs/Photos.rar"
    private static let top = ArchivePath(archive: archive)
    private static let inner = top.child("2024")
    private static let photo = inner.child("beach.jpg")

    let fileSystem = ChangingFileSystem()

    /// A tree with a folder `/docs` holding a zip, and that zip's inside.
    private func browser(at folder: FileItem.ID = "/docs") async throws -> BrowserState {
        let volume = try await fileSystem.item(at: "documents").volume
        fileSystem.add(FileItem(id: "/docs", name: "docs", kind: .folder, volume: volume))
        fileSystem.add(file(Self.archive, parent: "/docs", volume: volume))
        fileSystem.add(file("/docs/note.txt", parent: "/docs", volume: volume))
        fileSystem.add(
            FileItem(id: "/docs/Sub", name: "Sub", kind: .folder, parentID: "/docs", volume: volume)
        )
        // The fake's tree needs a parent that exists, so the top level hangs below the zip.
        fileSystem.add(
            FileItem(
                id: Self.top.id, name: "Photos.rar", kind: .folder, parentID: Self.archive,
                volume: Self.top.volume))
        fileSystem.add(
            FileItem(
                id: Self.inner.id, name: "2024", kind: .folder, parentID: Self.top.id,
                volume: Self.top.volume))
        fileSystem.add(file(Self.photo.id, parent: Self.inner.id, volume: Self.top.volume))
        return await makeBrowser(fileSystem: fileSystem, at: folder)
    }

    private func file(_ id: FileItem.ID, parent: FileItem.ID, volume: VolumeID) -> FileItem {
        FileItem(
            id: id, name: String(id.rawValue.split(separator: "/").last ?? ""), kind: .file,
            parentID: parent, volume: volume)
    }

    private func select(_ ids: Set<FileItem.ID>, in browser: BrowserState) {
        browser.setSelection(ids, in: browser.layout.focusedPane.activeTabID)
    }

    private func shown(_ browser: BrowserState) -> FileItem.ID {
        browser.layout.focusedPane.activeTab.folder
    }

    @Test func openingAnArchiveShowsItsTopLevel() async throws {
        let browser = try await browser()
        let zip = try await fileSystem.item(at: Self.archive)

        let result = await browser.open(zip, pane: 0, in: .samePane)

        #expect(result == .navigated)
        #expect(shown(browser) == Self.top.id)
        #expect(browser.focusedNames.contains("2024"))
    }

    @Test func anotherFileOpensInItsApp() async throws {
        let browser = try await browser()
        let note = try await fileSystem.item(at: "/docs/note.txt")

        #expect(await browser.open(note, pane: 0, in: .samePane) == .openFile(note))
    }

    @Test func anArchiveInsideAnArchiveOpensInItsApp() async throws {
        let browser = try await browser(at: Self.inner.id)
        let nested = Self.inner.child("Old.zip")
        fileSystem.add(file(nested.id, parent: Self.inner.id, volume: Self.top.volume))
        let item = try await fileSystem.item(at: nested.id)

        #expect(await browser.open(item, pane: 0, in: .samePane) == .openFile(item))
    }

    @Test func withoutAnArchiveEngineAnArchiveOpensInItsApp() async throws {
        let plain = PlainFileSystem(fileSystem)
        _ = try await browser()
        let browser = await makeBrowser(fileSystem: plain, at: "/docs")
        let zip = try await fileSystem.item(at: Self.archive)

        #expect(await browser.open(zip, pane: 0, in: .samePane) == .openFile(zip))
    }

    @Test func theTreeShowsAnArchiveAsItsTopLevelAmongTheFolders() async throws {
        let browser = try await browser()

        let rows = await browser.subfolders(of: "/docs")

        #expect(Set(rows.map(\.id)) == ["/docs/Sub", Self.top.id])
        #expect(rows.first { $0.id == Self.top.id }?.name == "Photos.rar")
    }

    @Test func theTreeHidesAHiddenArchive() async throws {
        let browser = try await browser()
        var hidden = file("/docs/.Secret.zip", parent: "/docs", volume: Self.top.volume)
        hidden.isHidden = true
        fileSystem.add(hidden)

        let rows = await browser.subfolders(of: "/docs")

        #expect(!rows.contains { $0.name == ".Secret.zip" })
    }

    @Test func insideAnArchiveNothingCanBeAddedOrChanged() async throws {
        let browser = try await browser(at: Self.inner.id)
        select([Self.photo.id], in: browser)

        #expect(!browser.canAddItems)
        #expect(!browser.canRenameSelection)
        #expect(!browser.canTrashSelection)
        #expect(!browser.canCutSelection)
        #expect(!browser.canCompressSelection)
        #expect(!browser.canSuggestNames)
    }

    @Test func insideAnArchiveCopyingStaysAvailable() async throws {
        let browser = try await browser(at: Self.inner.id)
        select([Self.photo.id], in: browser)

        #expect(browser.canCopySelection)
        browser.cutSelection()
        #expect(browser.clipboard == nil)
        browser.copySelection()
        #expect(browser.clipboard?.items.map(\.id) == [Self.photo.id])
    }

    @Test func anItemOnDiskCanBeCutAndCopied() async throws {
        let browser = try await browser()
        select(["/docs/note.txt"], in: browser)

        #expect(browser.canCutSelection)
        #expect(browser.canCopySelection)
    }

    @Test func aCopiedEntryPastesOutOfTheArchive() async throws {
        let browser = try await browser(at: Self.inner.id)
        select([Self.photo.id], in: browser)
        browser.copySelection()

        await browser.navigate(pane: 0, to: "/docs/Sub")
        await browser.paste(resolver: ScriptedResolver(), undoManager: nil)

        #expect(browser.focusedNames.contains("beach.jpg"))
        #expect(browser.failure == nil)
    }

    @Test func insideAnArchiveExtractAllExtractsThatArchive() async throws {
        let browser = try await browser(at: Self.inner.id)

        #expect(browser.canExtractSelection)
        #expect(await browser.archiveToExtract()?.id == Self.archive)
    }

    @Test func outsideAnArchiveExtractAllExtractsTheSelection() async throws {
        let browser = try await browser()
        select([Self.archive], in: browser)

        #expect(browser.canExtractSelection)
        #expect(await browser.archiveToExtract()?.id == Self.archive)
    }

    @Test func aPlaceInsideAnArchiveCannotBecomeAFavorite() async throws {
        let browser = try await browser()

        await browser.addFavorite(Self.inner.id)

        #expect(!browser.isFavorite(Self.inner.id))
    }

    @Test func thereIsNoTerminalInsideAnArchive() async throws {
        let browser = try await browser(at: Self.inner.id)
        select([Self.photo.id], in: browser)

        #expect(browser.terminalFolder == nil)
    }

    @Test func leavingAnArchiveReleasesWhatWasKeptOfIt() async throws {
        let browser = try await browser(at: Self.inner.id)

        await browser.navigate(pane: 0, to: "/docs")

        #expect(await fileSystem.eventuallyReleased(Self.archive))
    }

    @Test func goingThroughAnArchiveKeepsWhatWasKeptOfIt() async throws {
        let browser = try await browser(at: Self.inner.id)

        await browser.navigate(pane: 0, to: Self.top.id)

        #expect(fileSystem.releasedArchives.isEmpty)
    }

    @Test func anotherTabInTheArchiveKeepsWhatWasKeptOfIt() async throws {
        let browser = try await browser(at: Self.inner.id)
        await browser.openTab(pane: 0, at: Self.top.id)

        await browser.navigate(pane: 0, to: "/docs")

        #expect(fileSystem.releasedArchives.isEmpty)
    }
}

/// A provider that only reads: it has no archive engine.
private struct PlainFileSystem: FileSystemProviding {
    let base: ChangingFileSystem

    init(_ base: ChangingFileSystem) {
        self.base = base
    }

    func contents(of folder: FileItem.ID) async throws -> [FileItem] {
        try await base.contents(of: folder)
    }

    func item(at id: FileItem.ID) async throws -> FileItem {
        try await base.item(at: id)
    }

    func locations() async throws -> [FileItem] {
        try await base.locations()
    }

    func favorites() async throws -> [FileItem] {
        try await base.favorites()
    }

    func availableCapacity(of folder: FileItem.ID) async throws -> Int64? {
        try await base.availableCapacity(of: folder)
    }
}
