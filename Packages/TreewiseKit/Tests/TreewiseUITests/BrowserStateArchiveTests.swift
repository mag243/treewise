import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Extracting and compressing from the window (ADR 0074).
@MainActor
@Suite struct BrowserStateArchiveTests {
    let fileSystem = ChangingFileSystem()

    private func browser(at folder: FileItem.ID = "documents") async throws -> BrowserState {
        let documents = try await fileSystem.item(at: "documents")
        fileSystem.add(
            FileItem(
                id: "zip", name: "Photos.zip", kind: .file, parentID: "documents",
                volume: documents.volume))
        return await makeBrowser(fileSystem: fileSystem, at: folder)
    }

    private func select(_ ids: Set<FileItem.ID>, in browser: BrowserState) {
        browser.setSelection(ids, in: browser.layout.focusedPane.activeTabID)
    }

    private var selection: (BrowserState) -> Set<FileItem.ID> {
        { $0.content(of: $0.layout.focusedPane.activeTabID).selection }
    }

    @Test func extractsOneSelectedArchiveOnly() async throws {
        let browser = try await browser()
        select(["zip"], in: browser)
        #expect(browser.canExtractSelection)
        select(["doc2"], in: browser)
        #expect(!browser.canExtractSelection)
        select(["zip", "doc2"], in: browser)
        #expect(!browser.canExtractSelection)
        select([], in: browser)
        #expect(!browser.canExtractSelection)
    }

    @Test func compressesASelectionOnly() async throws {
        let browser = try await browser()
        #expect(!browser.canCompressSelection)
        select(["zip", "doc2"], in: browser)
        #expect(browser.canCompressSelection)
    }

    @Test func offersNothingWithoutAnArchiveEngine() async throws {
        let browser = await makeBrowser(fileSystem: Fixture.standard, at: "documents")
        select(["doc2"], in: browser)
        #expect(!browser.canCompressSelection)
    }

    @Test func extractsToAFolderNamedAfterTheArchiveAndSelectsIt() async throws {
        let browser = try await browser()
        select(["zip"], in: browser)

        await browser.extractSelection(to: "documents", undoManager: nil)

        #expect(browser.focusedNames.contains("Photos"))
        #expect(browser.failure == nil)
        let created = try #require(browser.selectedItems.first)
        #expect(created.name == "Photos")
        #expect(browser.renameRequest == nil)
    }

    @Test func aTakenFolderNameGetsCopy() async throws {
        _ = try await fileSystem.createFolder(in: "documents", named: "Photos")
        let browser = try await browser()
        select(["zip"], in: browser)

        await browser.extractSelection(to: "documents", undoManager: nil)

        #expect(browser.focusedNames.contains("Photos copy"))
    }

    @Test func extractingElsewhereKeepsTheSelection() async throws {
        let browser = try await browser()
        select(["zip"], in: browser)

        await browser.extractSelection(to: "projects", undoManager: nil)

        #expect(selection(browser) == ["zip"])
        let names = try await fileSystem.contents(of: "projects").map(\.name)
        #expect(names.contains("Photos"))
    }

    @Test func compressesNextToTheSelectionAfterItsFirstItemAndStartsRenaming() async throws {
        let browser = try await browser()
        select(["doc2", "zip"], in: browser)

        await browser.compressSelection(to: .zip, undoManager: nil)

        let created = try #require(browser.selectedItems.first)
        #expect(created.name == "Notes.zip")
        #expect(browser.renameRequest == created.id)
    }

    @Test(arguments: [(ArchiveFormat.sevenZip, "Notes.7z"), (.tarGzip, "Notes.tar.gz")])
    func namesTheArchiveForItsFormat(_ format: ArchiveFormat, _ expected: String) async throws {
        let browser = try await browser()
        select(["doc2"], in: browser)

        await browser.compressSelection(to: format, undoManager: nil)

        #expect(browser.focusedNames.contains(expected))
    }

    @Test func undoMovesTheNewArchiveToTheTrash() async throws {
        let browser = try await browser()
        let undoManager = UndoManager()
        select(["doc2"], in: browser)
        await browser.compressSelection(to: .zip, undoManager: undoManager)
        #expect(browser.focusedNames.contains("Notes.zip"))

        undoManager.undo()

        #expect(await eventually { !browser.focusedNames.contains("Notes.zip") })
        #expect(fileSystem.trashedIDs.count == 1)
    }

    @Test func aFailureIsShown() async throws {
        let browser = try await browser()
        select(["zip"], in: browser)
        fileSystem.failChanges(with: FileSystemError.archiveDamaged("zip"))

        await browser.extractSelection(to: "documents", undoManager: nil)

        #expect(browser.failure == .archiveDamaged("zip"))
    }

    @Test func reportsEntriesWhileItRunsAndStopsReporting() async throws {
        let browser = try await browser()
        select(["zip"], in: browser)
        fileSystem.holdChanges()

        let extraction = Task { await browser.extractSelection(to: "documents", undoManager: nil) }
        #expect(await eventually { browser.progress?.kind == .extracting })
        fileSystem.releaseChanges()
        await extraction.value

        #expect(browser.progress == nil)
    }

    @Test func stoppingIsNoFailureAndAddsNothing() async throws {
        let browser = try await browser()
        select(["doc2"], in: browser)
        fileSystem.holdChanges()

        let compression = Task { await browser.compressSelection(to: .zip, undoManager: nil) }
        #expect(await eventually { browser.progress?.kind == .compressing })
        browser.cancelOperation()
        fileSystem.releaseChanges()
        await compression.value

        #expect(browser.failure == nil)
        #expect(!browser.focusedNames.contains("Notes.zip"))
        #expect(browser.renameRequest == nil)
    }
}
