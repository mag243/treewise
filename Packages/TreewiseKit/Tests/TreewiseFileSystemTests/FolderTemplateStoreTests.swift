import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Templates kept in Treewise's own folder, one file each, named by the template's id
/// (ADR 0091, ADR 0097).
@Suite struct FolderTemplateStoreTests {
    private let root: TempDirectory
    private let store: FolderTemplateStore
    private static let year = FolderTemplate(
        id: "year", name: "Household Year",
        root: FolderTree(name: "{year}", folders: [FolderTree(name: "Tax")]))
    private static let client = FolderTemplate(
        id: "client", name: "Client", root: FolderTree(name: "{text}"))

    init() throws {
        root = try TempDirectory()
        store = FolderTemplateStore(directory: root.url("Templates"))
    }

    @Test func holdsNoTemplatesAtFirst() async {
        #expect(await store.templates().isEmpty)
    }

    @Test func keepsATemplateAcrossARestart() async throws {
        try await store.save(Self.year)
        let restarted = FolderTemplateStore(directory: root.url("Templates"))
        #expect(await restarted.templates() == [Self.year])
        #expect(FileManager.default.fileExists(atPath: root.url("Templates/year.json").path))
    }

    @Test func listsTheTemplatesByName() async throws {
        try await store.save(Self.year)
        try await store.save(Self.client)
        #expect(await store.templates().map(\.name) == ["Client", "Household Year"])
    }

    @Test func savesARenameUnderTheSameId() async throws {
        try await store.save(Self.year)
        var renamed = Self.year
        renamed.name = "Year"
        try await store.save(renamed)
        #expect(await store.templates() == [renamed])
    }

    @Test(.enabled(if: TrashAvailability.inTemporaryDirectory, "needs a Trash"))
    func deletesATemplateAndBringsItBack() async throws {
        try await store.save(Self.year)
        try await store.save(Self.client)
        let trashed = try await store.delete(id: "year")
        #expect(await store.templates() == [Self.client])
        try await store.restore(trashed)
        #expect(await store.templates() == [Self.client, Self.year])
    }

    /// Where Treewise's own folder has no Trash, as on the iPad, a deleted template's file
    /// is kept in a folder of the store's own until the next start, for Undo.
    @Test func deletesATemplateWhereThereIsNoTrashAndBringsItBack() async throws {
        let store = FolderTemplateStore(
            directory: root.url("Templates"),
            trash: { throw FileSystemError.trashUnavailable($0) })
        try await store.save(Self.year)
        try await store.save(Self.client)

        let trashed = try await store.delete(id: "year")

        #expect(await store.templates() == [Self.client])
        try await store.restore(trashed)
        #expect(await store.templates() == [Self.client, Self.year])
    }

    @Test func emptiesTheTemplatesDeletedWhereThereIsNoTrash() async throws {
        let store = FolderTemplateStore(
            directory: root.url("Templates"),
            trash: { throw FileSystemError.trashUnavailable($0) })
        try await store.save(Self.year)
        try await store.save(Self.client)
        let trashed = try await store.delete(id: "year")

        await store.emptyDeleted()

        #expect(!FileManager.default.fileExists(atPath: trashed.trashID.rawValue))
        #expect(await store.templates() == [Self.client], "the templates kept stay")
    }

    /// The same on a system whose temporary folder has no Trash, the iOS simulator.
    @Test(.disabled(if: TrashAvailability.inTemporaryDirectory, "needs a place without a Trash"))
    func deletesATemplateWithoutATrashOnThisSystem() async throws {
        try await store.save(Self.year)
        let trashed = try await store.delete(id: "year")
        #expect(await store.templates().isEmpty)
        try await store.restore(trashed)
        #expect(await store.templates() == [Self.year])
    }

    @Test func skipsAFileThatIsNoTemplate() async throws {
        try await store.save(Self.year)
        _ = try root.makeFile("Templates/broken.json", contents: "not json")
        _ = try root.makeFile("Templates/notes.txt", contents: "hello")
        #expect(await store.templates() == [Self.year])
    }

    @Test func importsATemplateHereAsANewOneWithANameOfItsOwn() async throws {
        try await store.save(Self.year)
        let data = try FolderTemplateFile.data(of: Self.year)
        let imported = try await store.importTemplate(from: data, keepingID: true)
        #expect(imported.id != Self.year.id, "an id here is not taken twice")
        #expect(imported.name == "Household Year 2")
        #expect(imported.root == Self.year.root)
        #expect(await store.templates().count == 2)
    }

    @Test func importKeepsTheFilesIDWhenNoTemplateHasIt() async throws {
        let data = try FolderTemplateFile.data(of: Self.year)
        let imported = try await store.importTemplate(from: data, keepingID: true)
        #expect(imported.id == Self.year.id)
        #expect(await store.templates() == [Self.year])
    }

    @Test func importGivesANewIDWhenNotKeepingIt() async throws {
        let data = try FolderTemplateFile.data(of: Self.year)
        let imported = try await store.importTemplate(from: data, keepingID: false)
        #expect(imported.id != Self.year.id)
    }

    @Test func saysAnImportThatCannotBeSavedIsNotSaved() async throws {
        try await store.save(Self.year)
        let folder = root.url("Templates")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: folder.path)
        }
        let data = try FolderTemplateFile.data(of: Self.client)
        await #expect(throws: FolderTemplateFile.Problem.notSaved) {
            try await store.importTemplate(from: data, keepingID: true)
        }
    }

    @Test func refusesToImportAFileThatIsNoTemplate() async {
        await #expect(throws: FolderTemplateFile.Problem.unreadable) {
            try await store.importTemplate(from: Data("nope".utf8), keepingID: true)
        }
    }
}
