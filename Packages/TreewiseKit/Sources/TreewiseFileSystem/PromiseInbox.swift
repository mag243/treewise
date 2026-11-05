import Foundation
import TreewiseCore

/// The hidden folder that files another app promised in a drag are received
/// into, inside the folder they were dropped on (ADR 0020). It sits on the
/// target's volume and inside the boundary, so copying out of it is an APFS
/// clone the runner accepts.
public enum PromiseInbox {
    /// The start of every inbox's name; a leading dot keeps it out of the list.
    static let prefix = ".treewise-inbox-"

    /// Creates a new, empty inbox in `folder`.
    ///
    /// - Throws: `FileSystemError.notWritable` or `.notFound` for the folder.
    public static func make(in folder: URL) throws -> URL {
        let inbox = folder.appendingPathComponent(prefix + UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: false)
        } catch {
            throw TrashService.error(error, for: FileItem.ID(folder.standardizedFileURL.path))
        }
        return inbox
    }

    /// Removes an inbox and what it received, once its files have been
    /// copied out. The inbox holds only what Treewise received during one
    /// drop, never a user's own file, so it is removed rather than trashed.
    ///
    /// Precondition: `inbox` is a folder made by `make(in:)`.
    public static func discard(_ inbox: URL) throws {
        precondition(
            inbox.lastPathComponent.hasPrefix(prefix), "inbox is a folder made by make(in:)")
        do {
            try FileManager.default.removeItem(at: inbox)
        } catch {
            throw TrashService.error(error, for: FileItem.ID(inbox.standardizedFileURL.path))
        }
    }
}
