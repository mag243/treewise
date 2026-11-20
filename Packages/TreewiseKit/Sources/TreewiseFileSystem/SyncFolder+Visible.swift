import Foundation
import TreewiseCore

/// The visible sync folder an iPad makes, read beside the hidden one and hidden on a Mac
/// with Hide Folder (ADR 0144).
extension SyncFolder {
    /// Whether the drive has the visible sync folder, which Hide Folder hides.
    public func usesVisibleFolder() -> Bool {
        existingDevicesFolders().contains {
            $0.deletingLastPathComponent().lastPathComponent == Self.visibleName
        }
    }

    /// Hides the visible sync folder: renames it `.treewise.settings`, or, where that is
    /// there, moves the devices' files into it, a newer file over an older one, and puts the
    /// visible folder in the Trash. Returns what went to the Trash, if anything.
    @discardableResult
    public func hideFolder() throws -> TrashedItem? {
        let visible = driveRoot.appending(path: Self.visibleName)
        let hidden = driveRoot.appending(path: Self.hiddenName)
        let folders = existingDevicesFolders().map {
            $0.deletingLastPathComponent().lastPathComponent
        }
        guard folders.contains(Self.visibleName) else { return nil }
        guard folders.contains(Self.hiddenName) else {
            try FileCoordination.move(visible, to: hidden) { source, target in
                try FileManager.default.moveItem(at: source, to: target)
            }
            return nil
        }
        let target = hidden.appending(path: Self.devicesName)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        for file in Self.files(in: visible.appending(path: Self.devicesName)) {
            let destination = target.appending(path: file.lastPathComponent)
            guard Self.isNewer(file, than: destination) else { continue }
            try FileCoordination.move(file, to: destination) { source, target in
                if FileManager.default.fileExists(atPath: target.path) {
                    _ = try FileManager.default.replaceItemAt(target, withItemAt: source)
                } else {
                    try FileManager.default.moveItem(at: source, to: target)
                }
            }
        }
        return try TrashService().trash(FileItem.ID(visible.path))
    }

    /// The devices' files of every sync folder there, of a device in both the newer.
    func deviceFiles() -> [URL] {
        var newest: [String: URL] = [:]
        for folder in existingDevicesFolders() {
            for file in Self.files(in: folder) {
                let name = file.lastPathComponent
                if newest[name].map({ Self.isNewer(file, than: $0) }) ?? true {
                    newest[name] = file
                }
            }
        }
        return newest.keys.sorted().compactMap { newest[$0] }
    }

    /// A folder's devices' files, listed through coordination.
    static func files(in folder: URL) -> [URL] {
        let names =
            (try? FileCoordination.read(folder) { url in
                try FileManager.default.contentsOfDirectory(atPath: url.path)
            }) ?? []
        return names.compactMap(deviceFileName).map { folder.appending(path: $0) }
    }

    /// Whether `file` was changed later than `other`, or `other` is not there.
    static func isNewer(_ file: URL, than other: URL) -> Bool {
        func modified(_ url: URL) -> Date? {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
        }
        guard let theirs = modified(other) else { return true }
        return (modified(file) ?? .distantPast) > theirs
    }
}
