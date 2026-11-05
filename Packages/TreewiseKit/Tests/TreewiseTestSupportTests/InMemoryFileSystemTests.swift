import Testing
import TreewiseCore
import TreewiseTestSupport

@Suite struct InMemoryFileSystemTests {
    let fileSystem = Fixture.standard

    @Test func listsTheItemsDirectlyInsideAFolder() async throws {
        let names = try await fileSystem.contents(of: "invoices").map(\.name).sorted()
        #expect(names == ["Invoice 2026-08.pdf", "Invoice 2026-09.pdf"])
    }

    @Test func findsAnItemByItsIdentity() async throws {
        let notes = try await fileSystem.item(at: "doc2")
        #expect(notes.name == "Notes.md")
        #expect(notes.parentID == "documents")
    }

    @Test func throwsNotFoundForAnUnknownItem() async {
        await #expect(throws: FileSystemError.notFound("nowhere")) {
            try await fileSystem.item(at: "nowhere")
        }
    }

    @Test func throwsNotFoundForTheContentsOfAnUnknownFolder() async {
        await #expect(throws: FileSystemError.notFound("nowhere")) {
            try await fileSystem.contents(of: "nowhere")
        }
    }

    @Test func reportsAncestorsNearestFirst() async throws {
        let ancestors = try await fileSystem.ancestorIDs(of: "s1")
        #expect(ancestors == ["src", "ptw", "projects", "home", "users", "hd"])
        #expect(fileSystem.ancestry("s1") == ancestors)
    }
}
