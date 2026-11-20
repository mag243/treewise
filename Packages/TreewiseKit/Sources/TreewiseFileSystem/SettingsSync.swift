import Foundation
import TreewiseCore
import os

/// Keeps this device's settings in sync through the `.treewise` folder of each cloud drive
/// that takes part (ADR 0144). The stores tell it what the user changed; `refresh()` reads
/// every device's files and returns what the stores must take over. A folder's settings
/// merge per drive; the saved patterns, the default and the templates across all drives,
/// and are written to each.
public actor SettingsSync {
    /// A change from another device, for a store to take over without recording it again.
    public enum Change: Hashable, Sendable {
        /// The settings of the folder at `path`, nil when they were removed.
        case folder(path: String, settings: FolderSettings?)
        case savedPattern(id: String, pattern: SavedPattern?)
        case defaultPattern(id: String)
        case template(id: String, template: FolderTemplate?)
    }

    private static let logger = Logger(subsystem: LogSubsystem.name, category: "Sync")
    private static let queue = DispatchQueue(label: "me.m-domain.treewise.sync", qos: .utility)

    private let device: SyncDevice
    private let now: @Sendable () -> Date
    private var drives: [URL] = []
    private var folderBooks: [String: SyncBook] = [:]
    private var shared: SyncBook
    private var written: [String: Set<SyncRecord>] = [:]

    /// A sync of `device`, its times from `now`.
    public init(device: SyncDevice, now: @escaping @Sendable () -> Date = Date.init) {
        self.device = device
        self.now = now
        shared = SyncBook(device: device.id)
    }

    /// The roots of the drives that take part.
    public func setDrives(_ roots: [URL]) {
        drives = roots.map(\.standardizedFileURL)
        for root in drives where folderBooks[root.path] == nil {
            folderBooks[root.path] = SyncBook(device: device.id)
        }
    }

    /// The user changed the settings of the folder at `path`, nil when they removed them;
    /// nothing for a folder outside the drives.
    public func folderChanged(at path: String, to settings: FolderSettings?) async {
        guard let (root, relative) = place(of: path) else { return }
        folderBooks[root]?.record(.folder(relative), settings.map(SyncValue.folder), now: now())
        await write(root)
    }

    /// Treewise moved the folder at `old` to `new`: its settings and those of the folders
    /// in it follow, also into another drive; out of the drives they are removed.
    public func folderMoved(from old: String, to new: String) async {
        guard let (oldRoot, oldPath) = place(of: old) else { return }
        let target = place(of: new)
        if let (newRoot, newPath) = target, newRoot == oldRoot {
            folderBooks[oldRoot]?.move(folder: oldPath, to: newPath, now: now())
        } else {
            let moving = (folderBooks[oldRoot]?.merged ?? [:]).values.filter {
                guard case .folder(let path) = $0.key, !$0.isRemoval else { return false }
                return path == oldPath || path.hasPrefix(oldPath + "/")
            }
            for record in moving {
                guard case .folder(let path) = record.key else { continue }
                folderBooks[oldRoot]?.record(record.key, nil, now: now())
                if let (newRoot, newPath) = target {
                    let inner = newPath + path.dropFirst(oldPath.count)
                    folderBooks[newRoot]?.record(.folder(inner), record.value, now: now())
                }
            }
            if let (newRoot, _) = target { await write(newRoot) }
        }
        await write(oldRoot)
    }

    /// The user changed a saved pattern, the default or a template; nil when they removed it.
    public func changed(_ key: SyncKey, to value: SyncValue?) async {
        shared.record(key, value, now: now())
        for root in drives { await write(root.path) }
    }

    /// Records the device's settings from before syncing, for keys no device's file has.
    /// Call after a first `refresh()`, so what the files hold is known.
    public func seed(folders: [String: FolderSettings], shared values: [SyncKey: SyncValue]) async {
        var byDrive: [String: [SyncKey: SyncValue]] = [:]
        for (path, settings) in folders {
            guard let (root, relative) = place(of: path) else { continue }
            byDrive[root, default: [:]][.folder(relative)] = .folder(settings)
        }
        for (root, values) in byDrive { folderBooks[root]?.seed(values) }
        shared.seed(values)
        for root in drives { await write(root.path) }
    }

    /// Reads every drive's files and returns the other devices' changes that now hold and
    /// were not taken over yet; writes this device's file where its records changed.
    public func refresh() async -> [Change] {
        let device = device
        let date = now()
        var sharedOthers: [SyncRecord] = []
        var sharedOwn: [SyncRecord] = []
        var changes: [Change] = []
        for root in drives {
            let folder = SyncFolder(driveRoot: root, device: device)
            let files: [DeviceSyncFile]
            do {
                files = try await Self.run { try folder.read().files }
            } catch {
                Self.logger.error("Sync files unreadable: \(error.localizedDescription)")
                continue
            }
            let own = files.filter { $0.device == device.id }.flatMap(\.records)
            let others = files.filter { $0.device != device.id }.flatMap(\.records)
            sharedOwn += own.filter { !$0.key.isFolder }
            sharedOthers += others.filter { !$0.key.isFolder }
            let taken =
                folderBooks[root.path]?.absorb(
                    others: others.filter(\.key.isFolder), ownInFile: own.filter(\.key.isFolder),
                    now: date) ?? []
            changes += taken.compactMap { Self.change(of: $0, in: root.path) }
        }
        let takenShared = shared.absorb(
            others: Self.unique(sharedOthers), ownInFile: sharedOwn, now: date)
        changes += takenShared.compactMap { Self.change(of: $0, in: "") }
        for root in drives { await write(root.path) }
        return changes
    }

    /// The drive holding `path`, and the path from its root.
    private func place(of path: String) -> (root: String, path: String)? {
        for root in drives {
            if let relative = SyncFolder.path(of: path, inDriveAt: root.path), !relative.isEmpty {
                return (root.path, relative)
            }
        }
        return nil
    }

    /// Writes this device's file in the drive at `root` when its records changed.
    private func write(_ root: String) async {
        let records = Set(
            (folderBooks[root]?.own.values.map { $0 } ?? []) + shared.own.values.map { $0 })
        guard written[root] != records else { return }
        let folder = SyncFolder(driveRoot: URL(filePath: root), device: device)
        let sorted = records.sorted { $0.key.text < $1.key.text }
        do {
            try await Self.run { try folder.write(sorted) }
            written[root] = records
        } catch {
            Self.logger.error("Sync file not written: \(error.localizedDescription)")
        }
    }

    private static func change(of record: SyncRecord, in root: String) -> Change? {
        switch (record.key, record.value) {
        case (.folder(let path), let value):
            guard case .folder(let settings)? = value else {
                return .folder(path: root + "/" + path, settings: nil)
            }
            return .folder(path: root + "/" + path, settings: settings)
        case (.savedPattern(let id), .savedPattern(let pattern)?):
            return .savedPattern(id: id, pattern: pattern)
        case (.savedPattern(let id), nil): return .savedPattern(id: id, pattern: nil)
        case (.defaultPattern, .defaultPattern(let id)?): return .defaultPattern(id: id)
        case (.template(let id), .template(let template)?):
            return .template(id: id, template: template)
        case (.template(let id), nil): return .template(id: id, template: nil)
        default: return nil
        }
    }

    /// The same record read from several drives, once.
    private static func unique(_ records: [SyncRecord]) -> [SyncRecord] {
        Array(Set(records))
    }

    private static func run<Value: Sendable>(
        _ body: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try body() }) }
        }
    }
}

extension SyncKey {
    /// Whether the key is a folder's, merged per drive.
    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}

extension SettingsSync {
    /// Records what the user changed in a folder's settings.
    public func handle(_ notice: FolderSettingsNotice) async {
        switch notice {
        case .changed(let path, let settings): await folderChanged(at: path, to: settings)
        case .moved(let old, let new): await folderMoved(from: old, to: new)
        }
    }

    /// Records what the user changed in the templates.
    public func handle(_ notice: FolderTemplateNotice) async {
        switch notice {
        case .saved(let template):
            await changed(.template(template.id), to: .template(template))
        case .deleted(let id): await changed(.template(id), to: nil)
        }
    }
}
