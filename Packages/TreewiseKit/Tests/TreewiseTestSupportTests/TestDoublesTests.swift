import Testing
import TreewiseCore
import TreewiseTestSupport

@Suite struct TestDoublesTests {
    @Test func removesAFolderWithEverythingInside() async throws {
        let fileSystem = ChangingFileSystem()
        fileSystem.remove("documents")
        await #expect(throws: FileSystemError.notFound("invoices")) {
            try await fileSystem.item(at: "invoices")
        }
        #expect(try await fileSystem.item(at: "home").name == "Home")
    }

    @Test func addsAnItem() async throws {
        let fileSystem = ChangingFileSystem()
        fileSystem.add(
            FileItem(id: "new", name: "new.txt", kind: .file, parentID: "desktop", volume: "hd"))
        #expect(try await fileSystem.contents(of: "desktop").contains { $0.id == "new" })
    }

    @Test func sendsChangesToTheWatchersOfAFolder() async {
        let watcher = ManualFolderWatcher()
        var events = watcher.changes(of: "documents").makeAsyncIterator()
        #expect(watcher.watchedFolders == ["documents"])
        watcher.change("documents")
        #expect(await events.next() != nil)
    }
}
