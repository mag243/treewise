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

    @Test func deletesATemplateAndBringsItBack() async throws {
        try await store.save(Self.year)
        try await store.save(Self.client)
        let trashed = try await store.delete(id: "year")
        #expect(await store.templates() == [Self.client])
        try await store.restore(trashed)
        #expect(await store.templates() == [Self.client, Self.year])
    }

    @Test func skipsAFileThatIsNoTemplate() async throws {
        try await store.save(Self.year)
        _ = try root.makeFile("Templates/broken.json", contents: "not json")
        _ = try root.makeFile("Templates/notes.txt", contents: "hello")
        #expect(await store.templates() == [Self.year])
    }

    @Test func importsAFileAsANewTemplateWithANameOfItsOwn() async throws {
        try await store.save(Self.year)
        let data = try FolderTemplateFile.data(of: Self.year)
        let imported = try await store.importTemplate(from: data)
        #expect(imported.id != Self.year.id)
        #expect(imported.name == "Household Year 2")
        #expect(imported.root == Self.year.root)
        #expect(await store.templates().count == 2)
    }

    @Test func refusesToImportAFileThatIsNoTemplate() async {
        await #expect(throws: FolderTemplateFile.Problem.unreadable) {
            try await store.importTemplate(from: Data("nope".utf8))
        }
    }
}
