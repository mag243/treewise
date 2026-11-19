import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Settings kept by a folder's path, where the volume refuses Treewise's id, follow the
/// folder when Treewise moves or renames it (ADR 0057).
@Suite struct FolderSettingsMoveTests {
    private let root: TempDirectory
    private let store: FolderSettingsStore
    private let settings = FolderSettings(enabledModules: ["a"], templates: ["a": "{seq}"])

    init() throws {
        root = try TempDirectory()
        try root.makeFolder("private")
        store = FolderSettingsStore(directory: root.url("private"))
    }

    /// Saves settings kept by the path, as on a volume that refuses the id: saved while
    /// nothing is there to take the id, then the folder made.
    private func savedByPath(_ relativePath: String) async throws -> String {
        let path = root.url(relativePath).path
        await store.save(settings, forFolderAt: path)
        try root.makeFolder(relativePath)
        #expect(FolderSettingsStore.id(onFolderAt: path) == nil)
        return path
    }

    @Test func settingsByPathFollowAFolderMoved() async throws {
        let old = try await savedByPath("Belastingsdienst")
        let new = root.url("Belastingdienst").path
        await store.folderMoved(from: old, to: new)
        #expect(await store.settings(forFolderAt: new) == settings)
        #expect(await store.settings(forFolderAt: old) == nil)
    }

    @Test func settingsByPathOfAFolderInsideFollowToo() async throws {
        try root.makeFolder("2025")
        let inside = try await savedByPath("2025/Belastingsdienst")
        await store.folderMoved(from: root.url("2025").path, to: root.url("2024").path)
        let moved = root.url("2024/Belastingsdienst").path
        #expect(await store.settings(forFolderAt: moved) == settings)
        #expect(await store.settings(forFolderAt: inside) == nil)
    }

    @Test func aFolderWhoseNameStartsTheSameStaysWhereItIs() async throws {
        let other = try await savedByPath("Belasting 2")
        await store.folderMoved(
            from: root.url("Belasting").path, to: root.url("Belastingdienst").path)
        #expect(await store.settings(forFolderAt: other) == settings)
    }

    @Test func renamingByTheRunnerTakesTheSettingsAlong() async throws {
        let old = try await savedByPath("Belastingsdienst")
        let runner = FileOperationRunner(folderSettings: store)
        let folder = try await runner.item(at: FileItem.ID(old))
        let renamed = try await runner.rename(folder, to: "Belastingdienst")
        let new = try #require(renamed.items.first).id.rawValue
        #expect(await store.settings(forFolderAt: new) == settings)
    }
}
