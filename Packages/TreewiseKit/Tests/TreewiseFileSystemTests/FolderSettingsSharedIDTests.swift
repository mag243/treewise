import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// A folder in a cloud drive is seen by every device, with whatever id another device put
/// on it: a device keeps that id rather than writing its own over it (ADR 0144).
@Suite struct FolderSettingsSharedIDTests {
    private static func settings(_ module: String) -> FolderSettings {
        FolderSettings(enabledModules: [module], templates: [:])
    }

    @Test func aDeviceKeepsTheIDAnotherPutOnTheFolder() async throws {
        let drive = try TempDirectory()
        let folder = try drive.makeFolder("Clients").path
        let mac = FolderSettingsStore(directory: try TempDirectory().url)
        let ipad = FolderSettingsStore(directory: try TempDirectory().url)
        await mac.save(Self.settings("a"), forFolderAt: folder)
        let id = FolderSettingsStore.id(onFolderAt: folder)

        await ipad.save(Self.settings("b"), forFolderAt: folder)

        #expect(FolderSettingsStore.id(onFolderAt: folder) == id)
        #expect(await mac.settings(forFolderAt: folder) == Self.settings("a"))
        #expect(await ipad.settings(forFolderAt: folder) == Self.settings("b"))
    }

    @Test func settingsKeptByPathAreFoundWhenAnotherDevicePutAnIDOnTheFolder() async throws {
        let drive = try TempDirectory()
        let folder = try drive.makeFolder("Clients").path
        let mac = FolderSettingsStore(directory: try TempDirectory().url)
        let ipad = FolderSettingsStore(directory: try TempDirectory().url)
        await ipad.save(Self.settings("b"), forFolderAt: folder)
        let ipadID = FolderSettingsStore.id(onFolderAt: folder)
        _ = removexattr(folder, "me.m-domain.treewise.folder-id", 0)
        await mac.save(Self.settings("a"), forFolderAt: folder)
        let macID = FolderSettingsStore.id(onFolderAt: folder)
        #expect(macID != nil && macID != ipadID)

        #expect(await ipad.settings(forFolderAt: folder) == Self.settings("b"))
        #expect(FolderSettingsStore.id(onFolderAt: folder) == macID, "the id stays")
    }
}
