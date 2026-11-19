import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Settings live in Treewise's own folder, and only an id goes on the folder (ADR 0057).
@Suite struct FolderSettingsStoreTests {
    private let root: TempDirectory
    private let store: FolderSettingsStore
    private let settings = FolderSettings(
        enabledModules: ["a"], templates: ["a": "Secret {number}"])

    init() throws {
        root = try TempDirectory()
        try root.makeFolder("private")
        store = FolderSettingsStore(directory: root.url("private"))
    }

    @Test func aNewFolderHasNoSettings() async throws {
        #expect(await store.settings(forFolderAt: try root.makeFolder("A").path) == nil)
    }

    @Test func givesBackWhatWasSaved() async throws {
        let path = try root.makeFolder("A").path
        await store.save(settings, forFolderAt: path)
        #expect(await store.settings(forFolderAt: path) == settings)
    }

    @Test func keepsSettingsOverARestart() async throws {
        let path = try root.makeFolder("A").path
        await store.save(settings, forFolderAt: path)
        let restarted = FolderSettingsStore(directory: root.url("private"))
        #expect(await restarted.settings(forFolderAt: path) == settings)
    }

    /// Settings kept under an add-on's former id are read with its current one, and the
    /// file is saved so at once (ADR 0140).
    @Test func savesSettingsKeptUnderAFormerIDUnderTheCurrentOne() async throws {
        let (old, new) = (
            "me.m-domain.treewise.folder-pattern",
            AddOnIDs.current(
                "me.m-domain.treewise.folder-pattern")
        )
        let path = try root.makeFolder("A").path
        await store.save(
            FolderSettings(enabledModules: [old], templates: [old: "{year} Tax"]),
            forFolderAt: path)
        let restarted = FolderSettingsStore(directory: root.url("private"))
        #expect(await restarted.settings(forFolderAt: path)?.templates == [new: "{year} Tax"])
        let file = root.url("private").appendingPathComponent(FolderSettingsStore.fileName)
        #expect(!AddOnIDs.holdsFormerID(try String(contentsOf: file, encoding: .utf8)))
    }

    @Test func putsNothingButARandomIDOnTheFolder() async throws {
        let path = try root.makeFolder("A").path
        await store.save(settings, forFolderAt: path)
        let id = try #require(FolderSettingsStore.id(onFolderAt: path))
        #expect(UUID(uuidString: id) != nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: path).isEmpty)
    }

    @Test func givesTwoFoldersDifferentIDs() async throws {
        let first = try root.makeFolder("A").path
        let second = try root.makeFolder("B").path
        await store.save(settings, forFolderAt: first)
        await store.save(settings, forFolderAt: second)
        #expect(
            FolderSettingsStore.id(onFolderAt: first) != FolderSettingsStore.id(onFolderAt: second))
    }

    @Test func followsAMovedFolder() async throws {
        let path = try root.makeFolder("A").path
        await store.save(settings, forFolderAt: path)
        let moved = try root.moveFolder(atPath: path, to: "Moved")
        #expect(await store.settings(forFolderAt: moved) == settings)
        #expect(await store.settings(forFolderAt: path) == nil)
    }

    @Test func givesACopyItsOwnSettings() async throws {
        let path = try root.makeFolder("A").path
        await store.save(settings, forFolderAt: path)
        let copy = root.url("Copy").path
        try FileManager.default.copyItem(atPath: path, toPath: copy)
        #expect(
            FolderSettingsStore.id(onFolderAt: copy) == FolderSettingsStore.id(onFolderAt: path))

        #expect(await store.settings(forFolderAt: copy) == settings)
        #expect(
            FolderSettingsStore.id(onFolderAt: copy) != FolderSettingsStore.id(onFolderAt: path))
        let changed = FolderSettings(enabledModules: ["b"], templates: [:])
        await store.save(changed, forFolderAt: copy)
        #expect(await store.settings(forFolderAt: path) == settings)
        #expect(await store.settings(forFolderAt: copy) == changed)
    }

    @Test func ignoresAnIDFromAnotherTreewise() async throws {
        let path = try root.makeFolder("A").path
        await store.save(settings, forFolderAt: path)
        try root.makeFolder("elsewhere")
        let stranger = FolderSettingsStore(directory: root.url("elsewhere"))
        #expect(await stranger.settings(forFolderAt: path) == nil)
    }

    @Test func givesAStrangersFolderANewIDWhenSaving() async throws {
        let path = try root.makeFolder("A").path
        await store.save(settings, forFolderAt: path)
        let theirs = FolderSettingsStore.id(onFolderAt: path)
        try root.makeFolder("elsewhere")
        let stranger = FolderSettingsStore(directory: root.url("elsewhere"))
        await stranger.save(settings, forFolderAt: path)
        #expect(FolderSettingsStore.id(onFolderAt: path) != theirs)
    }

    @Test func keepsThePatternOutOfTheFoldersAttributes() async throws {
        let path = try root.makeFolder("A").path
        await store.save(settings, forFolderAt: path)
        let names = listxattr(path, nil, 0, 0)
        var buffer = [CChar](repeating: 0, count: max(names, 1))
        _ = listxattr(path, &buffer, buffer.count, 0)
        let attributes = String(bytes: buffer.map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? ""
        #expect(!attributes.contains("Secret"))
        #expect(FolderSettingsStore.id(onFolderAt: path)?.contains("Secret") == false)
    }

    @Test func survivesADamagedFile() async throws {
        let path = try root.makeFolder("A").path
        try Data("not json".utf8).write(
            to: root.url("private").appendingPathComponent(FolderSettingsStore.fileName))
        #expect(await store.settings(forFolderAt: path) == nil)
        await store.save(settings, forFolderAt: path)
        #expect(await store.settings(forFolderAt: path) == settings)
    }

    @Test func usesThePathWhenAFolderTakesNoID() async {
        // A folder that does not exist refuses the attribute, as some volumes do.
        let path = root.url("gone").path
        await store.save(settings, forFolderAt: path)
        #expect(FolderSettingsStore.id(onFolderAt: path) == nil)
        #expect(await store.settings(forFolderAt: path) == settings)
    }

    @Test func aNewFolderAtAnOldPathGetsNoSettings() async throws {
        let path = try root.makeFolder("A").path
        await store.save(settings, forFolderAt: path)
        _ = try root.moveFolder(atPath: path, to: "Moved")
        try root.makeFolder("A")
        #expect(await store.settings(forFolderAt: path) == nil)
    }

    @Test func handlesAContentTypeWithItsSubtypes() {
        #expect(ModuleScope.handles(contentTypes: ["public.image"], contentType: "public.png"))
        #expect(!ModuleScope.handles(contentTypes: ["com.adobe.pdf"], contentType: "public.png"))
        #expect(!ModuleScope.handles(contentTypes: ["public.image"], contentType: "not a type"))
    }
}
