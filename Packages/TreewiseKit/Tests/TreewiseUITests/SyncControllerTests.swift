import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport
import TreewiseUI

/// The app's side of syncing (ADR 0144): the switch, the saved patterns between devices,
/// and the safety net with Restore.
@MainActor
@Suite struct SyncControllerTests {
    /// A device: its settings, stores and controller, and the folders they live in.
    @MainActor
    private struct Device {
        let settings: BrowserSettings
        let folders: FolderSettingsStore
        let controller: SyncController
        let support: TempDirectory

        init(_ id: String, minutesAfter offset: @escaping @Sendable () -> Double) throws {
            support = try TempDirectory()
            settings = BrowserSettings(store: MemorySettingsStore())
            folders = FolderSettingsStore(directory: support.url)
            let start = Date(timeIntervalSince1970: 2_000_000_000)
            let now: @Sendable () -> Date = { start.addingTimeInterval(offset() * 60) }
            let session = SyncSession(
                sync: SettingsSync(device: SyncDevice(id: id, name: id), now: now),
                folders: folders,
                templates: FolderTemplateStore(directory: support.url.appending(path: "T")))
            controller = SyncController(
                settings: settings, session: session,
                conflicts: SyncConflictStore(directory: support.url), now: now)
        }
    }

    @Test func savedPatternsChangedOnOneDeviceReachTheOther() async throws {
        let drive = try TempDirectory()
        let mac = try Device("a-mac") { 0 }
        let ipad = try Device("b-ipad") { 1 }
        await mac.controller.start(drives: [drive.url])
        await ipad.controller.start(drives: [drive.url])

        _ = mac.settings.savedPatterns.save(name: "Tax", text: "Tax - {text}")
        await mac.controller.settle()
        await ipad.controller.refresh()

        #expect(ipad.settings.savedPatterns.patterns.map(\.name).contains("Tax"))
    }

    @Test func withTheSwitchOffNothingIsWrittenInTheDrive() async throws {
        let drive = try TempDirectory()
        let mac = try Device("a-mac") { 0 }
        mac.settings.syncsSettings = false
        await mac.controller.start(drives: [drive.url])

        _ = mac.settings.savedPatterns.save(name: "Tax", text: "Tax - {text}")
        await mac.controller.settle()

        #expect(
            !FileManager.default.fileExists(
                atPath: drive.url.appending(path: ".treewise.settings/devices/a-mac.json").path))
    }

    @Test func aReplacedChangeIsListedAndRestoreBringsItBack() async throws {
        let drive = try TempDirectory()
        let folder = try drive.makeFolder("Clients").path
        let mac = try Device("a-mac") { 0 }
        let ipad = try Device("b-ipad") { 1 }
        await mac.controller.start(drives: [drive.url])
        await ipad.controller.start(drives: [drive.url])
        await mac.folders.save(
            FolderSettings(enabledModules: ["mine"], templates: [:]), forFolderAt: folder)
        await ipad.folders.save(
            FolderSettings(enabledModules: ["theirs"], templates: [:]), forFolderAt: folder)
        await mac.controller.settle()
        await ipad.controller.settle()

        await mac.controller.refresh()

        let entry = try #require(mac.controller.replaced.first)
        #expect(entry.byDevice == "b-ipad")
        await mac.controller.restore(entry)
        #expect(mac.controller.replaced.isEmpty)
        #expect(
            await mac.folders.settings(forFolderAt: folder)?.enabledModules == ["mine"])
    }

    @Test func aDriveAddedWhileSyncingTakesPart() async throws {
        let first = try TempDirectory()
        let second = try TempDirectory()
        let folder = try second.makeFolder("Clients").path
        let mac = try Device("a-mac") { 0 }
        await mac.folders.save(
            FolderSettings(enabledModules: ["dates"], templates: [:]), forFolderAt: folder)
        await mac.controller.start(drives: [first.url])

        await mac.controller.start(drives: [first.url, second.url])
        await mac.controller.settle()

        #expect(
            FileManager.default.fileExists(
                atPath: second.url.appending(path: ".treewise.settings/devices/a-mac.json").path))
    }

    @Test func aDeviceThatMakesNoFolderSaysTheDriveHasNotStarted() async throws {
        let drive = try TempDirectory()
        let settings = BrowserSettings(store: MemorySettingsStore())
        let support = try TempDirectory()
        let folders = FolderSettingsStore(directory: support.url)
        let controller = SyncController(
            settings: settings,
            session: SyncSession(
                sync: SettingsSync(
                    device: SyncDevice(id: "ipad", name: "iPad"), making: { _ in .none }),
                folders: folders, templates: FolderTemplateStore(directory: support.url)),
            conflicts: SyncConflictStore(directory: support.url))
        let folder = try drive.makeFolder("Clients").path
        await folders.save(
            FolderSettings(enabledModules: ["dates"], templates: [:]), forFolderAt: folder)

        await controller.start(drives: [drive.url])

        #expect(controller.driveProblems[drive.url.standardizedFileURL.path] == .notStarted)
        #expect(try FileManager.default.contentsOfDirectory(atPath: drive.path) == ["Clients"])
    }
}
