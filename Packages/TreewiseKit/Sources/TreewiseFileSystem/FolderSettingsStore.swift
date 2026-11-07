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
        subsystem: "me.m-domain.treewise", category: "FolderSettingsStore")

    private struct Record: Codable {
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
            lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen) ?? Date()
        }
    }

    private let file: URL
    private var records: [String: Record]?

    /// Creates a store that keeps its file in `directory`.
    public init(directory: URL) {
        file = directory.appendingPathComponent(Self.fileName)
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

    /// The settings of a folder, or nil when it has none. This follows a folder that
    /// moved, and gives a copy an id and settings of its own.
    public func settings(forFolderAt path: String) -> FolderSettings? {
        loadIfNeeded()
        return settledID(forFolderAt: path).flatMap { records?[$0]?.settings }
    }

    /// Saves the settings of a folder, giving it an id when it has none of ours.
    public func save(_ settings: FolderSettings, forFolderAt path: String) {
        loadIfNeeded()
        if let id = settledID(forFolderAt: path) {
            records?[id]?.settings = settings
            records?[id]?.lastSeen = Date()
        } else {
            let id = UUID().uuidString
            let isOnFolder = Self.write(id, toFolderAt: path)
            records?[id] = Record(
                path: path, isOnFolder: isOnFolder, settings: settings, lastSeen: Date())
        }
        persist()
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
        records = [:]
        persist()
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
    private func settledID(forFolderAt path: String) -> String? {
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
            return nil
        case .moved:
            guard let id else { return nil }
            records?[id]?.path = path
            records?[id]?.lastSeen = Date()
            persist()
            return id
        case .copy:
            return id.flatMap { split(copyOf: $0, at: path) }
        }
    }

    private func split(copyOf id: String, at path: String) -> String? {
        guard let record = records?[id] else { return nil }
        let new = UUID().uuidString
        guard Self.write(new, toFolderAt: path) else { return nil }
        records?[new] = Record(
            path: path, isOnFolder: true, settings: record.settings, lastSeen: Date())
        persist()
        return new
    }

    private static func write(_ id: String, toFolderAt path: String) -> Bool {
        let bytes = Array(id.utf8)
        return setxattr(path, attributeName, bytes, bytes.count, 0, 0) == 0
    }

    private func loadIfNeeded() {
        guard records == nil else { return }
        guard let data = try? Data(contentsOf: file) else {
            records = [:]
            return
        }
        do {
            records = try JSONDecoder().decode([String: Record].self, from: data)
        } catch {
            // Patterns can be recognized again, so a damaged file does not stop anything.
            Self.logger.error("Folder settings unreadable: \(error.localizedDescription)")
            records = [:]
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(records ?? [:]).write(to: file, options: .atomic)
        } catch {
            Self.logger.error("Folder settings not saved: \(error.localizedDescription)")
        }
    }
}
