import Foundation
import TreewiseCore

/// A cloud drive's `.treewise/devices` folder (ADR 0144): this device writes only its own
/// file there and reads every device's, each access coordinated, so a provider fetches a
/// file kept only online first and hears of each change.
///
/// Its methods block on file coordination: run them off Swift's cooperative pool.
public struct SyncFolder: Sendable {
    /// The folder at a drive's root, hidden by its dot.
    static let folderName = ".treewise"
    /// The folder of the devices' files inside it.
    static let devicesName = "devices"
    private static let fileExtension = "json"

    /// The drive's root.
    public let driveRoot: URL
    /// This device.
    public let device: SyncDevice

    /// What was read: every device's file, and the files that could not be read.
    public struct Reading: Sendable {
        public let files: [DeviceSyncFile]
        public let skipped: [URL]
    }

    /// The folder of the drive at `driveRoot`, as `device` sees it.
    public init(driveRoot: URL, device: SyncDevice) {
        self.driveRoot = driveRoot
        self.device = device
    }

    /// The folder of the devices' files.
    public var devicesFolder: URL {
        driveRoot.appending(path: Self.folderName).appending(path: Self.devicesName)
    }

    private var ownFile: URL {
        devicesFolder.appending(path: device.id).appendingPathExtension(Self.fileExtension)
    }

    /// Writes this device's file with `records`, making the folders it needs.
    ///
    /// - Throws: `DeviceSyncFile.Problem.newerFormat` when its file there was written by a
    ///   newer Treewise, which it leaves as it is; an error of the file system otherwise.
    public func write(_ records: [SyncRecord]) throws {
        let file = DeviceSyncFile(device: device.id, name: device.name, records: records)
        let data = try file.encoded()
        try FileManager.default.createDirectory(
            at: devicesFolder, withIntermediateDirectories: true)
        try FileCoordination.write(ownFile) { url in
            if let existing = try? Data(contentsOf: url) {
                do {
                    _ = try DeviceSyncFile.decoded(from: existing)
                } catch let problem as DeviceSyncFile.Problem {
                    throw problem
                } catch {
                    // A file of its own that cannot be read is this device's to replace.
                }
            }
            try data.write(to: url, options: .atomic)
        }
    }

    /// Reads every device's file; one that cannot be read is skipped and left as it is.
    /// A drive without the folder reads as no files.
    public func read() throws -> Reading {
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: devicesFolder.path)
        } catch CocoaError.fileReadNoSuchFile {
            return Reading(files: [], skipped: [])
        }
        var files: [DeviceSyncFile] = []
        var skipped: [URL] = []
        for name in names.compactMap(Self.deviceFileName).sorted() {
            let url = devicesFolder.appending(path: name)
            do {
                let data = try FileCoordination.read(url) { try Data(contentsOf: $0) }
                files.append(try DeviceSyncFile.decoded(from: data))
            } catch {
                skipped.append(url)
            }
        }
        return Reading(files: files, skipped: skipped)
    }

    /// A presenter of the devices' folder, which calls `onChange` when a device's file
    /// appears or changes, as the provider brings another device's change. The caller
    /// registers it with `NSFileCoordinator.addFilePresenter(_:)` and removes it again.
    public func presenter(onChange: @escaping @Sendable () -> Void) -> FolderPresenter {
        FolderPresenter(folder: devicesFolder, onChange: onChange)
    }

    /// The name of a device's file listed as `name`: a `.json` file, or one iCloud Drive
    /// keeps only online under a placeholder (`.name.json.icloud`); nil for anything else.
    static func deviceFileName(_ name: String) -> String? {
        let placeholder = ".icloud"
        if name.hasPrefix("."), name.hasSuffix(placeholder) {
            return deviceFileName(String(name.dropFirst().dropLast(placeholder.count)))
        }
        return name.hasSuffix("." + fileExtension) && !name.hasPrefix(".") ? name : nil
    }

    /// The path of the folder at `folder` from the drive's root at `root`, its parts joined
    /// by `/`, empty for the root itself; nil for a folder outside the drive.
    public static func path(of folder: String, inDriveAt root: String) -> String? {
        let base = root.hasSuffix("/") ? String(root.dropLast()) : root
        if folder == base { return "" }
        guard folder.hasPrefix(base + "/") else { return nil }
        return String(folder.dropFirst(base.count + 1))
    }
}
