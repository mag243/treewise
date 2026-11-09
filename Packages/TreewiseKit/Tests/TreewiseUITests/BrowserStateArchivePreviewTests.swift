import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Files out of an archive for Quick Look, opening and dragging (ADR 0076).
@MainActor
@Suite struct BrowserStateArchivePreviewTests {
    private static let top = ArchivePath(archive: "/docs/Photos.zip")
    private static let photo = top.child("beach.jpg")

    let fileSystem = ChangingFileSystem()

    private struct Setup {
        var browser: BrowserState
        var entry: FileItem
        var onDisk: FileItem
    }

    private func setUp() async throws -> Setup {
        let volume = try await fileSystem.item(at: "documents").volume
        fileSystem.add(FileItem(id: "/docs", name: "docs", kind: .folder, volume: volume))
        fileSystem.add(
            FileItem(id: "/docs/Sub", name: "Sub", kind: .folder, parentID: "/docs", volume: volume)
        )
        let onDisk = FileItem(
            id: "/docs/note.txt", name: "note.txt", kind: .file, parentID: "/docs", volume: volume)
        fileSystem.add(onDisk)
        let entry = FileItem(
            id: Self.photo.id, name: "beach.jpg", kind: .file, parentID: "/docs",
            volume: Self.top.volume)
        fileSystem.add(entry)
        let browser = await makeBrowser(fileSystem: fileSystem, at: "/docs")
        return Setup(browser: browser, entry: entry, onDisk: onDisk)
    }

    @Test func aFileOnDiskIsPreviewedWhereItIs() async throws {
        let setup = try await setUp()

        let urls = await setup.browser.previewURLs(for: [setup.onDisk])

        #expect(urls.map(\.path) == ["/docs/note.txt"])
    }

    @Test func anEntryIsPreviewedFromItsCopy() async throws {
        let setup = try await setUp()

        let urls = await setup.browser.previewURLs(for: [setup.entry])

        #expect(urls.map(\.path) == ["/cache/beach.jpg"])
        #expect(setup.browser.failure == nil)
    }

    @Test func anEntryThatCannotBeReadIsReported() async throws {
        let setup = try await setUp()
        fileSystem.failChanges(with: FileSystemError.archivePasswordProtected("/docs/Photos.zip"))

        let urls = await setup.browser.previewURLs(for: [setup.entry])

        #expect(urls.isEmpty)
        #expect(setup.browser.failure == .archivePasswordProtected("/docs/Photos.zip"))
    }

    @Test func aPromisedDropCopiesTheEntryToTheFileAsked() async throws {
        let setup = try await setUp()

        try await setup.browser.copyOut(
            setup.entry, toFileAt: URL(fileURLWithPath: "/docs/Sub/renamed.jpg"))

        let names = try await fileSystem.contents(of: "/docs/Sub").map(\.name)
        #expect(names == ["renamed.jpg"])
    }
}
