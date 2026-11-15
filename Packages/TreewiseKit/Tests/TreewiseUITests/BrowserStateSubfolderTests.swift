import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Whether a sidebar folder has subfolders, known beforehand only where its folder reads
/// quickly (ADR 0108).
@MainActor
@Suite struct BrowserStateSubfolderTests {
    /// The fixture, read as if every folder were in the cloud.
    private struct SlowReading: FileSystemProviding {
        let tree = Fixture.standard
        func contents(of folder: FileItem.ID) async throws -> [FileItem] {
            try await tree.contents(of: folder)
        }
        func item(at id: FileItem.ID) async throws -> FileItem { try await tree.item(at: id) }
        func locations() async throws -> [FileItem] { try await tree.locations() }
        func favorites() async throws -> [FileItem] { try await tree.favorites() }
        func availableCapacity(of folder: FileItem.ID) async throws -> Int64? { nil }
    }

    @Test func knowsAFolderHasSubfolders() async {
        let browser = await makeBrowser()
        #expect(await browser.subfolderPresence(in: "documents") == .present)
    }

    @Test func knowsAFolderOfFilesHasNone() async {
        let browser = await makeBrowser()
        #expect(await browser.subfolderPresence(in: "invoices") == .absent)
    }

    @Test func countsAHiddenFolderOnlyWhenHiddenFilesShow() async {
        let fileSystem = ChangingFileSystem()
        fileSystem.add(
            FileItem(
                id: "dotfolder", name: ".cache", kind: .folder, parentID: "invoices", volume: "hd",
                isHidden: true))
        let settings = BrowserSettings(store: MemorySettingsStore())
        let browser = await makeBrowser(fileSystem: fileSystem, settings: settings)
        #expect(await browser.subfolderPresence(in: "invoices") == .absent)
        settings.showsHiddenFiles = true
        #expect(await browser.subfolderPresence(in: "invoices") == .present)
    }

    @Test func doesNotTellWhereAFolderDoesNotReadQuickly() async {
        let browser = await makeBrowser(fileSystem: SlowReading())
        #expect(await browser.subfolderPresence(in: "documents") == .unknown)
    }
}
