import Foundation
import Synchronization
import TreewiseCore
import TreewiseTestSupport

@testable import TreewiseFileSystem

/// One device for the sync tests (ADR 0144): its support folder, stores and session.
struct SyncTestDevice {
    let folders: FolderSettingsStore
    let templates: FolderTemplateStore
    let session: SyncSession
    let clock: SyncTestClock
    /// Kept so its folder lasts as long as the device.
    let support: TempDirectory

    init(_ id: String, support: TempDirectory, clock: SyncTestClock) {
        self.support = support
        folders = FolderSettingsStore(directory: support.url)
        templates = FolderTemplateStore(directory: support.url.appending(path: "Templates"))
        self.clock = clock
        let sync = SettingsSync(device: SyncDevice(id: id, name: id), now: { clock.now })
        session = SyncSession(sync: sync, folders: folders, templates: templates)
    }
}

/// A clock the test moves on.
final class SyncTestClock: Sendable {
    private let time = Mutex(Date(timeIntervalSince1970: 2_000_000_000))
    var now: Date { time.withLock { $0 } }
    func advance(_ seconds: TimeInterval = 60) {
        time.withLock { $0 = $0.addingTimeInterval(seconds) }
    }
}

/// Two devices and the drive they share.
struct SyncTestPair {
    let mac: SyncTestDevice
    let ipad: SyncTestDevice
    let drive: TempDirectory

    static func make() throws -> SyncTestPair {
        let clock = SyncTestClock()
        return SyncTestPair(
            mac: SyncTestDevice("a-mac", support: try TempDirectory(), clock: clock),
            ipad: SyncTestDevice("b-ipad", support: try TempDirectory(), clock: clock),
            drive: try TempDirectory())
    }

    static func settings(_ module: String) -> FolderSettings {
        FolderSettings(enabledModules: [module], templates: [:])
    }
}
