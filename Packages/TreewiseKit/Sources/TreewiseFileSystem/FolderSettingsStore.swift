import Foundation
import TreewiseCore
import os

/// Keeps `FolderSettings` in Treewise's own folder and finds them again through a
/// random id in an extended attribute on the folder, so a folder that is shared carries
/// nothing about its patterns (ADR 0057). A volume that refuses the attribute makes the
/// path the key, and the settings then follow a folder only when Treewise moves it.
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
        } else {
            let id = UUID().uuidString
            let isOnFolder = Self.write(id, toFolderAt: path)
            records?[id] = Record(path: path, isOnFolder: isOnFolder, settings: settings)
        }
        persist()
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
        records?[new] = Record(path: path, isOnFolder: true, settings: record.settings)
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
