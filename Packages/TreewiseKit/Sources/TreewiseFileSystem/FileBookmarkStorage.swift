import Foundation
import TreewiseCore
import os

/// Keeps bookmarks as JSON in a file of the app's own container, such as
/// Application Support, so they survive a relaunch (ADR 0045).
public struct FileBookmarkStorage: BookmarkStorage {
    private static let logger = Logger(subsystem: LogSubsystem.name, category: "bookmarks")

    /// The file the bookmarks are kept in; its folder is made when missing.
    public let file: URL

    /// Creates storage in `file`.
    public init(file: URL) {
        self.file = file
    }

    /// Returns the saved bookmarks; none when the file is missing or unreadable.
    public func load() -> [Bookmark] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        do {
            return try JSONDecoder().decode([Bookmark].self, from: data)
        } catch {
            Self.logger.error("Unreadable bookmarks: \(error.localizedDescription)")
            return []
        }
    }

    /// Saves the bookmarks, replacing the file atomically. A file that is there but cannot
    /// be read is left as it is, as `load()` gave none of its bookmarks.
    public func save(_ bookmarks: [Bookmark]) {
        guard !Self.isUnreadable(file) else {
            Self.logger.error("Bookmarks not saved: their file cannot be read")
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(bookmarks).write(to: file, options: .atomic)
        } catch {
            Self.logger.error("Bookmarks not saved: \(error.localizedDescription)")
        }
    }

    /// Whether a file is there and cannot be read; a missing one can be written.
    private static func isUnreadable(_ file: URL) -> Bool {
        do {
            try FileHandle(forReadingFrom: file).close()
            return false
        } catch CocoaError.fileReadNoSuchFile, CocoaError.fileNoSuchFile {
            return false
        } catch {
            return true
        }
    }
}
