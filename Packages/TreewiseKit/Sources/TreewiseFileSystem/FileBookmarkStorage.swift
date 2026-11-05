import Foundation
import os

/// Keeps bookmarks as JSON in a file of the app's own container, such as
/// Application Support, so they survive a relaunch (ADR 0045).
public struct FileBookmarkStorage: BookmarkStorage {
    private static let logger = Logger(subsystem: "me.m-domain.treewise", category: "bookmarks")

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

    /// Saves the bookmarks, replacing the file atomically.
    public func save(_ bookmarks: [Bookmark]) {
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(bookmarks).write(to: file, options: .atomic)
        } catch {
            Self.logger.error("Bookmarks not saved: \(error.localizedDescription)")
        }
    }
}
