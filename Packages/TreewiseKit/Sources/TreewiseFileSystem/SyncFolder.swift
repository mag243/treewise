import Foundation
import TreewiseCore

/// A cloud drive's sync folder (ADR 0144): this device writes only its own file in its
/// `devices` folder and reads every device's, each access coordinated, so a provider brings
/// what it keeps only online first and hears of each change. The folder is the hidden
/// `.treewise.settings` a Mac makes, or the visible `Treewise.Settings` an iPad makes when
/// asked, as the Dropbox app on iOS renames a folder made there whose name starts with a dot.
///
/// Its methods block on file coordination: run them off Swift's cooperative pool.
public struct SyncFolder: Sendable {
    /// The folder a Mac makes at a drive's root, hidden by its dot.
    static let hiddenName = ".treewise.settings"
    /// The folder an iPad or iPhone makes when the user asks, for a drive no Mac syncs.
    static let visibleName = "Treewise.Settings"
    /// The folder of the devices' files inside it.
    static let devicesName = "devices"
    private static let fileExtension = "json"

    /// Which folder this device makes when the drive has none.
    public enum Making: Sendable {
        /// The hidden folder, as a Mac makes it.
        case hidden
        /// The visible folder, as an iPad makes it when asked.
        case visible
        /// None: the device waits for another to make one.
        case none
    }

    /// Why this device does not sync in the drive.
    public enum Problem: Error, Equatable, Sendable {
        /// The drive has no sync folder and this device makes none.
        case notStarted
        /// The folder made is not there under its name: the provider renamed it.
        case renamed
    }

    /// The drive's root.
    public let driveRoot: URL
    /// This device.
    public let device: SyncDevice
    /// Which folder this device makes when there is none.
    public let making: Making

    /// What was read: every device's file, and the files that could not be read.
    public struct Reading: Sendable {
        public let files: [DeviceSyncFile]
        public let skipped: [URL]
    }

    /// The folder of the drive at `driveRoot`, as `device` sees it, making `making` when
    /// the drive has none.
    public init(driveRoot: URL, device: SyncDevice, making: Making = .hidden) {
        self.driveRoot = driveRoot
        self.device = device
        self.making = making
    }

    /// The devices' folder of the sync folder there, the hidden one first; nil when the
    /// drive has none. Looked for through coordination, so a provider brings it first.
    public func existingDevicesFolder() -> URL? {
        for name in [Self.hiddenName, Self.visibleName] {
            let folder = driveRoot.appending(path: name)
            let isThere =
                (try? FileCoordination.read(folder) { url in
                    var isFolder: ObjCBool = false
                    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder)
                        && isFolder.boolValue
                }) ?? false
            if isThere { return folder.appending(path: Self.devicesName) }
        }
        return nil
    }

    /// The devices' folder to watch: the one there, or the hidden one a Mac would make.
    public var devicesFolder: URL {
        existingDevicesFolder()
            ?? driveRoot.appending(path: Self.hiddenName).appending(path: Self.devicesName)
    }

    /// The devices' folder, made as `making` says when the drive has none.
    ///
    /// - Throws: `Problem.notStarted` when it makes none, `Problem.renamed` when the folder
    ///   made is not there under its name.
    private func madeDevicesFolder() throws -> URL {
        if let existing = existingDevicesFolder() {
            try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
            return existing
        }
        let name: String
        switch making {
        case .hidden: name = Self.hiddenName
        case .visible: name = Self.visibleName
        case .none: throw Problem.notStarted
        }
        let folder = driveRoot.appending(path: name)
        try FileCoordination.write(folder) { url in
            try FileManager.default.createDirectory(
                at: url.appending(path: Self.devicesName), withIntermediateDirectories: true)
        }
        guard let made = existingDevicesFolder(),
            made.deletingLastPathComponent().lastPathComponent == name
        else {
            throw Problem.renamed
        }
        return made
    }

    /// Writes this device's file with `records`, making the folders it needs.
    ///
    /// - Throws: `Problem.notStarted` or `Problem.renamed` when there is no folder to write
    ///   in; `DeviceSyncFile.Problem.newerFormat` when its file there was written by a
    ///   newer Treewise, which it leaves as it is; an error of the file system otherwise.
    public func write(_ records: [SyncRecord]) throws {
        let file = DeviceSyncFile(device: device.id, name: device.name, records: records)
        let data = try file.encoded()
        let ownFile = try madeDevicesFolder().appending(path: device.id)
            .appendingPathExtension(Self.fileExtension)
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
        guard let devicesFolder = existingDevicesFolder() else {
            return Reading(files: [], skipped: [])
        }
        let names: [String]
        do {
            names = try FileCoordination.read(devicesFolder) { url in
                try FileManager.default.contentsOfDirectory(atPath: url.path)
            }
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
