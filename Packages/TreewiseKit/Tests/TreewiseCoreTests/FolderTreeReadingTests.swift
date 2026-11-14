import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

/// Reading a folder's tree from what it holds, for saving it as a template (ADR 0091).
@Suite struct FolderTreeReadingTests {
    private let fileSystem = ChangingFileSystem()

    private func add(_ name: String, _ kind: ItemKind, in parent: FileItem.ID, hidden: Bool = false)
        async throws -> FileItem
    {
        let above = try await fileSystem.item(at: parent)
        let item = FileItem(
            id: FileItem.ID("\(parent.rawValue)/\(name)"), name: name, kind: kind,
            parentID: parent, volume: above.volume, isHidden: hidden)
        fileSystem.add(item)
        return item
    }

    @Test func readsTheFoldersAtEveryDepthAndNothingElse() async throws {
        let year = try await add("2026", .folder, in: "documents")
        let tax = try await add("Tax", .folder, in: year.id)
        _ = try await add("Returns", .folder, in: tax.id)
        _ = try await add("Receipts", .folder, in: year.id)
        _ = try await add("Overview.numbers", .file, in: year.id)
        _ = try await add(".git", .folder, in: year.id, hidden: true)
        _ = try await add("Photos.photoslibrary", .package, in: year.id)
        let tree = try await fileSystem.folderTree(of: year)
        #expect(tree.name == "2026")
        #expect(tree.folders.map(\.name) == ["Receipts", "Tax"])
        #expect(tree.folders[1].folders.map(\.name) == ["Returns"])
    }

    @Test func stopsAtTheMostLevels() async throws {
        var parent = try await add("Deep", .folder, in: "documents")
        let top = parent
        for level in 1..<FolderTree.mostLevels + 1 {
            parent = try await add("Level \(level)", .folder, in: parent.id)
        }
        await #expect(throws: FolderTree.Problem.tooDeep) {
            try await fileSystem.folderTree(of: top)
        }
    }
}
