import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Clearing folder settings, and dropping those of folders long unseen (ADR 0072).
@Suite struct FolderSettingsStoreCleanupTests {
    private let root: TempDirectory
    private let store: FolderSettingsStore
    private let settings = FolderSettings(enabledModules: ["a"], templates: ["a": "Scan {seq}"])
    private static let day: TimeInterval = 24 * 60 * 60

    init() throws {
        root = try TempDirectory()
        try root.makeFolder("private")
        store = FolderSettingsStore(directory: root.url("private"))
    }

    private func folder(_ name: String) throws -> String {
        try root.makeFolder(name).path
    }

    private func moveFolder(_ from: String, to name: String) throws -> String {
        let target = root.url(name).path
        try FileManager.default.moveItem(atPath: from, toPath: target)
        return target
    }

    private func days(_ count: Double) -> Date {
        Date().addingTimeInterval(count * Self.day)
    }

    @Test func dropsTheSettingsOfAFolderUnseenForMoreThanThirtyDays() async throws {
        let path = try folder("A")
        await store.save(settings, forFolderAt: path)
        let moved = try moveFolder(path, to: "Moved")
        await store.dropSettingsOfUnseenFolders(now: days(31))
        #expect(await store.settings(forFolderAt: moved) == nil)
    }

    @Test func keepsTheSettingsOfAFolderUnseenForLess() async throws {
        let path = try folder("A")
        await store.save(settings, forFolderAt: path)
        let moved = try moveFolder(path, to: "Moved")
        await store.dropSettingsOfUnseenFolders(now: days(29))
        #expect(await store.settings(forFolderAt: moved) == settings)
    }

    @Test func aFolderFoundAtItsPathCountsAsSeen() async throws {
        let path = try folder("A")
        await store.save(settings, forFolderAt: path)
        await store.dropSettingsOfUnseenFolders(now: days(20))
        let moved = try moveFolder(path, to: "Moved")
        await store.dropSettingsOfUnseenFolders(now: days(40))
        #expect(await store.settings(forFolderAt: moved) == settings)
    }

    @Test func anotherFolderAtThePathDoesNotCountAsSeen() async throws {
        let path = try folder("A")
        await store.save(settings, forFolderAt: path)
        let moved = try moveFolder(path, to: "Moved")
        try root.makeFolder("A")
        await store.dropSettingsOfUnseenFolders(now: days(31))
        #expect(await store.settings(forFolderAt: moved) == nil)
    }

    @Test func keepsTheSettingsOfAFolderOnADiskThatIsNotAttached() async {
        // No disk is mounted under this name, and a path that is not there takes no id.
        let path = "/Volumes/Treewise-absent-\(UUID().uuidString)/A"
        await store.save(settings, forFolderAt: path)
        await store.dropSettingsOfUnseenFolders(now: days(400))
        #expect(await store.settings(forFolderAt: path) == settings)
    }

    @Test func aDroppedFolderStaysDroppedOverARestart() async throws {
        let path = root.url("gone").path
        await store.save(settings, forFolderAt: path)
        await store.dropSettingsOfUnseenFolders(now: days(31))
        let restarted = FolderSettingsStore(directory: root.url("private"))
        #expect(await restarted.settings(forFolderAt: path) == nil)
    }

    @Test func settingsSavedBeforeTheyHadADateStartTheirThirtyDaysWhenRead() async throws {
        let path = root.url("gone").path
        let old = #"{"enabledModules":["a"],"templates":{}}"#
        let record = #"{"path":"\#(path)","isOnFolder":false,"settings":\#(old)}"#
        try Data(#"{"old":\#(record)}"#.utf8).write(
            to: root.url("private").appendingPathComponent(FolderSettingsStore.fileName))
        await store.dropSettingsOfUnseenFolders(now: days(29))
        #expect(await store.settings(forFolderAt: path) != nil)
        await store.dropSettingsOfUnseenFolders(now: days(31))
        #expect(await store.settings(forFolderAt: path) == nil)
    }

    @Test func clearsTheSettingsOfEveryFolder() async throws {
        let first = try folder("A")
        let second = root.url("gone").path
        await store.save(settings, forFolderAt: first)
        await store.save(settings, forFolderAt: second)
        await store.clearAll()
        #expect(await store.settings(forFolderAt: first) == nil)
        #expect(await store.settings(forFolderAt: second) == nil)
        let restarted = FolderSettingsStore(directory: root.url("private"))
        #expect(await restarted.settings(forFolderAt: first) == nil)
    }

    @Test func aClearedFolderGetsNewSettingsWhenSaved() async throws {
        let path = try folder("A")
        await store.save(settings, forFolderAt: path)
        await store.clearAll()
        let changed = FolderSettings(enabledModules: ["b"], templates: [:])
        await store.save(changed, forFolderAt: path)
        #expect(await store.settings(forFolderAt: path) == changed)
    }
}
