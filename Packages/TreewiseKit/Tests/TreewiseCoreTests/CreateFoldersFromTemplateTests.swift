import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

/// Making a template's folders in a folder, as one step for Undo (ADR 0091).
@Suite struct CreateFoldersFromTemplateTests {
    private let fileSystem = ChangingFileSystem()
    private let household: FileItem
    private static let tree = FolderTree(
        name: "2027",
        folders: [
            FolderTree(name: "Insurance"), FolderTree(name: "Receipts"),
            FolderTree(
                name: "Tax", folders: [FolderTree(name: "Letters"), FolderTree(name: "Returns")]),
        ])

    init() async throws {
        let documents = try await fileSystem.item(at: "documents")
        household = try await fileSystem.createFolder(in: documents.id, named: "Household")
    }

    private func names(in folder: FileItem.ID) async throws -> [String] {
        try await fileSystem.contents(of: folder).map(\.name).sorted()
    }

    private func folder(_ name: String, in parent: FileItem.ID) async throws -> FileItem {
        try #require(try await fileSystem.contents(of: parent).first { $0.name == name })
    }

    @Test func makesTheWholeTree() async throws {
        let outcome = try await fileSystem.createFolders(making: Self.tree, in: household.id)
        #expect(outcome.madeCount == 6)
        let year = try await folder("2027", in: household.id)
        #expect(try await names(in: year.id) == ["Insurance", "Receipts", "Tax"])
        let tax = try await folder("Tax", in: year.id)
        #expect(try await names(in: tax.id) == ["Letters", "Returns"])
    }

    @Test func fillsWhatIsThereAndLeavesOutWhatAFileStops() async throws {
        let year = try await fileSystem.createFolder(in: household.id, named: "2027")
        let tax = try await fileSystem.createFolder(in: year.id, named: "Tax")
        _ = try await fileSystem.createFolder(in: tax.id, named: "Returns")
        fileSystem.add(
            FileItem(
                id: "insurance-file", name: "Insurance", kind: .file, parentID: year.id,
                volume: year.volume))
        let outcome = try await fileSystem.createFolders(making: Self.tree, in: household.id)
        #expect(outcome.madeCount == 2)
        #expect(outcome.leftOut == [["2027", "Insurance"]])
        #expect(try await names(in: year.id) == ["Insurance", "Receipts", "Tax"])
        #expect(try await names(in: tax.id) == ["Letters", "Returns"])
    }

    @Test func undoesEveryFolderMadeAtOnceAndKeepsWhatWasThere() async throws {
        let year = try await fileSystem.createFolder(in: household.id, named: "2027")
        let outcome = try await fileSystem.createFolders(making: Self.tree, in: household.id)
        #expect(Set(outcome.result.items.map(\.name)) == ["Insurance", "Receipts", "Tax"])
        _ = try await fileSystem.undo(outcome.result.undo)
        #expect(try await names(in: household.id) == ["2027"])
        #expect(try await names(in: year.id).isEmpty)
    }
}
