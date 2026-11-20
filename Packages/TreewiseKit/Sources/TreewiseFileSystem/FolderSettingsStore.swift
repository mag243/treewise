import Foundation
import TreewiseCore
import os

/// Keeps `FolderSettings` in Treewise's own folder and finds them again through a
/// random id in an extended attribute on the folder, so a folder that is shared carries
/// nothing about its patterns (ADR 0057). A volume that refuses the attribute makes the
/// path the key, and the settings then follow a folder only when Treewise moves it.
/// The settings of a folder long unseen go on their own, and all of them on request
/// (ADR 0072).
public actor FolderSettingsStore: FolderSettingsStoring {
    /// The name of the file that holds the settings.
    public static let fileName = "folder-settings.json"
    private static let attributeName = "me.m-domain.treewise.folder-id"
    private static let logger = Logger(
        subsystem: LogSubsystem.name, category: "FolderSettingsStore")

    struct Record: Codable {
        var path: String
        /// Whether the id is on the folder. If not, the path is all that finds it.
        var isOnFolder: Bool
        var settings: FolderSettings
        /// When the folder was last seen. A record saved without one counts as seen when
        /// it is read, which starts its time.
        var lastSeen: Date

        init(path: String, isOnFolder: Bool, settings: FolderSettings, lastSeen: Date) {
            self.path = path
            self.isOnFolder = isOnFolder
            self.settings = settings
            self.lastSeen = lastSeen
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            path = try container.decode(String.self, forKey: .path)
            isOnFolder = try container.decode(Bool.self, forKey: .isOnFolder)
            settings = try container.decode(FolderSettings.self, forKey: .settings)
            lastSeen =
                try container.decodeIfPresent(Date.self, forKey: .lastSeen)
                ?? decoder.userInfo[Record.readingTime] as? Date ?? Date()
        }

        // swiftlint:disable force_unwrapping - a fixed key, which is always valid
        /// The store's time when it reads its file, for a record saved without a date.
        static let readingTime = CodingUserInfoKey(rawValue: "readingTime")!
        // swiftlint:enable force_unwrapping
    }

    private let file: URL
    /// The settings by the id on each folder; nil until the file is read.
    var records: [String: Record]?
    /// Where what the user changes is told, in order, for a sync to record (ADR 0144).
    var notices: NoticeLine<FolderSettingsNotice>?
    /// Whether the file is there but could not be read: then it is never written, so the
    /// settings of every folder in it are not lost; changes last until the app quits.
    private var isFileUnreadable = false

    /// When a folder is seen, as its settings are read or saved.
    private let now: @Sendable () -> Date

    /// Creates a store that keeps its file in `directory`, telling the time by `now`.
    public init(directory: URL, now: @escaping @Sendable () -> Date = Date.init) {
        file = directory.appendingPathComponent(Self.fileName)
        self.now = now
    }

    /// The folder Treewise keeps these settings in by default.
    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Treewise", isDirectory: true)
    }

    /// The id on a folder, if it has one.
    public static func id(onFolderAt path: String) -> String? {
        let size = getxattr(path, attributeName, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard getxattr(path, attributeName, &bytes, size, 0, 0) == size else { return nil }
        return String(bytes: bytes, encoding: .utf8)
    }

    /// Moves the settings kept by path of the folder at `old`, and of every folder in it,
    /// to `new`, as Treewise moved or renamed it there.
    /// A folder that carries its id needs none of this: the id finds it wherever it is.
    public func folderMoved(from old: String, to new: String) {
        loadIfNeeded()
        let inside = old + "/"
        var moved = false
        for (id, record) in records ?? [:] where !record.isOnFolder {
            guard record.path == old || record.path.hasPrefix(inside) else { continue }
            records?[id]?.path = new + record.path.dropFirst(old.count)
            moved = true
        }
        if moved { persist() }
        notices?.tell(.moved(from: old, to: new))
    }

    /// The settings of a folder, or nil when it has none. This follows a folder that
    /// moved, and gives a copy an id and settings of its own.
    public func settings(forFolderAt path: String) -> FolderSettings? {
        loadIfNeeded()
        return settledID(forFolderAt: path).flatMap { records?[$0]?.settings }
    }

    /// Saves the settings of a folder, giving it an id when it has none of ours.
    public func save(_ settings: FolderSettings, forFolderAt path: String) {
        loadIfNeeded()
        let settled = settledID(forFolderAt: path)
        let before = settled.flatMap { records?[$0]?.settings }
        if let id = settled {
            records?[id]?.settings = settings
            records?[id]?.lastSeen = now()
        } else {
            // An id another device put on the folder is kept, not written over (ADR 0144).
            let onFolder = Self.id(onFolderAt: path)
            let id = onFolder ?? UUID().uuidString
            let isOnFolder = onFolder != nil || Self.write(id, toFolderAt: path)
            records?[id] = Record(
                path: path, isOnFolder: isOnFolder, settings: settings, lastSeen: now())
        }
        persist()
        notices?.tell(.changed(path: path, before: before, after: settings))
    }

    /// Drops the settings of every folder that has not been seen for a while on a disk that
    /// is attached, and marks the folders found at their paths as seen (ADR 0072).
    public func dropSettingsOfUnseenFolders(now: Date) {
        loadIfNeeded()
        guard let current = records else { return }
        for (id, record) in current {
            let verdict = FolderSettingsCleanup.verdict(
                isThere: Self.isThere(record, id: id),
                diskIsAttached: FileManager.default.fileExists(
                    atPath: FolderSettingsCleanup.disk(of: record.path)),
                lastSeen: record.lastSeen, now: now)
            switch verdict {
            case .seen: records?[id]?.lastSeen = now
            case .keep: break
            case .drop: records?[id] = nil
            }
        }
        persist()
    }

    /// Removes the settings of every folder. The ids on the folders stay and mean nothing
    /// without their records (ADR 0072).
    public func clearAll() {
        loadIfNeeded()
        let cleared = (records ?? [:]).values.map { ($0.path, $0.settings) }
        records = [:]
        persist()
        for (path, before) in cleared {
            notices?.tell(.changed(path: path, before: before, after: nil))
        }
    }

    /// Whether a record's folder is at its path: a folder, carrying the record's id when
    /// the record's id is on its folder.
    private static func isThere(_ record: Record, id: String) -> Bool {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: record.path, isDirectory: &isFolder),
            isFolder.boolValue
        else { return false }
        return !record.isOnFolder || Self.id(onFolderAt: record.path) == id
    }

    /// The id whose record belongs to this folder, after bringing the record up to date.
    func settledID(forFolderAt path: String) -> String? {
        let id = Self.id(onFolderAt: path)
        let recordedPath = id.flatMap { records?[$0]?.path }
        let place = FolderSettings.place(
            idOnFolder: id, path: path, recordedPath: recordedPath,
            idAtRecordedPath: recordedPath.flatMap(Self.id(onFolderAt:)))
        switch place {
        case .same:
            return id
        case .noID:
            return records?.first { !$0.value.isOnFolder && $0.value.path == path }?.key
        case .unknownID:
            return adopt(id, forFolderAt: path)
        case .moved:
            guard let id else { return nil }
            records?[id]?.path = path
            records?[id]?.lastSeen = now()
            persist()
            return id
        case .copy:
            return id.flatMap { split(copyOf: $0, at: path) }
        }
    }

    /// The record kept by path for the folder at `path`, kept from now on under `id`, the
    /// id another device put on the folder (ADR 0144); nil when there is none.
    private func adopt(_ id: String?, forFolderAt path: String) -> String? {
        guard let id, let kept = records?.first(where: { $0.value.path == path })?.key,
            var record = records?[kept]
        else { return nil }
        record.isOnFolder = true
        records?[kept] = nil
        records?[id] = record
        persist()
        return id
    }

    private func split(copyOf id: String, at path: String) -> String? {
        guard let record = records?[id] else { return nil }
        let new = UUID().uuidString
        guard Self.write(new, toFolderAt: path) else { return nil }
        records?[new] = Record(
            path: path, isOnFolder: true, settings: record.settings, lastSeen: now())
        persist()
        return new
    }

    private static func write(_ id: String, toFolderAt path: String) -> Bool {
        let bytes = Array(id.utf8)
        return setxattr(path, attributeName, bytes, bytes.count, 0, 0) == 0
    }

    func loadIfNeeded() {
        guard records == nil else { return }
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch CocoaError.fileReadNoSuchFile {
            records = [:]
            return
        } catch {
            Self.logger.error(
                "Folder settings unreadable, left as they are: \(error.localizedDescription)")
            isFileUnreadable = true
            records = [:]
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.userInfo[Record.readingTime] = now()
            records = try decoder.decode([String: Record].self, from: data)
            // The settings were read with the add-ons' current ids; the file is saved with
            // them once, so it holds no former id (ADR 0140).
            if String(bytes: data, encoding: .utf8).map(AddOnIDs.holdsFormerID) == true {
                persist()
            }
        } catch {
            // Patterns can be recognized again, so a damaged file does not stop anything.
            Self.logger.error("Folder settings unreadable: \(error.localizedDescription)")
            records = [:]
        }
    }

    func persist() {
        guard !isFileUnreadable else { return }
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(records ?? [:]).write(to: file, options: .atomic)
        } catch {
            Self.logger.error("Folder settings not saved: \(error.localizedDescription)")
        }
    }
}
