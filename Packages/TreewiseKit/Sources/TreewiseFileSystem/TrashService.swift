import Foundation
import TreewiseCore

/// Moves items to the Trash and back (ADR 0004, ADR 0018). Deleting always
/// goes through here; nothing is removed for good.
public struct TrashService: Sendable {
    /// Creates the service.
    public init() {}

    /// Whether callers leave `trashItem` without a coordinated access of their own, as on
    /// iOS: there it hands the item to its provider, which coordinates it, and on iOS 27 a
    /// coordinated write around it waits for ever, as the two wait on each other (ADR 0047).
    /// On the Mac it does not coordinate, so callers do.
    public static let coordinatesItself: Bool = {
        #if os(iOS)
            true
        #else
            false
        #endif
    }()

    /// Moves an item to the Trash of its volume.
    ///
    /// - Returns: the item's identity in the Trash, with where it came from.
    /// - Throws: `notFound`, `notWritable`, or `trashUnavailable` when the
    ///   volume has no Trash.
    public func trash(_ id: FileItem.ID) throws -> TrashedItem {
        // iOS answers "no Trash" before it looks for the item; a missing item
        // is not found wherever it is. A broken symbolic link still counts.
        guard (try? FileManager.default.attributesOfItem(atPath: id.rawValue)) != nil else {
            throw FileSystemError.notFound(id)
        }
        var trashURL: NSURL?
        do {
            try FileManager.default.trashItem(
                at: URL(fileURLWithPath: id.rawValue), resultingItemURL: &trashURL)
        } catch {
            throw FileSystemError.mapping(error, for: id)
        }
        guard let path = trashURL?.path else { throw FileSystemError.trashUnavailable(id) }
        return TrashedItem(trashID: FileItem.ID(path), originalID: id)
    }

    /// Moves an item back from the Trash to where it was.
    ///
    /// - Throws: `notFound` when the Trash has been emptied of it, `alreadyExists`
    ///   when its old place is taken.
    public func restore(_ trashed: TrashedItem) throws {
        do {
            try FileManager.default.moveItem(
                at: URL(fileURLWithPath: trashed.trashID.rawValue),
                to: URL(fileURLWithPath: trashed.originalID.rawValue))
        } catch {
            throw FileSystemError.mapping(error, for: trashed.originalID)
        }
    }
}
