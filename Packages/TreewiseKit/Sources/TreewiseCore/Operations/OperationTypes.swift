/// What to do when an item lands in a folder that already holds its name.
public enum ConflictDecision: Sendable, Hashable {
    /// Move the item in the folder to the Trash and put the new one in its place.
    case replace
    /// Keep both: the new item gets a copy name (`ConflictResolver`).
    case keepBoth
    /// Stop the operation; items handled before stay where they went.
    case stop
}

/// Decides name conflicts during an operation, for example by asking the user.
/// "Apply to all" is the resolver remembering its answer.
public protocol ConflictResolving: Sendable {
    /// Returns what to do with `incoming` now that `existing` holds its name.
    func decide(existing: FileItem, incoming: FileItem) async -> ConflictDecision
}

/// How far an operation is (ADR 0021): a transfer in the bytes it copies, an
/// archive operation in its entries, as `tar` reports no bytes (ADR 0074).
public struct OperationProgress: Sendable, Hashable {
    /// What an operation with progress does, which says what it counts.
    public enum Kind: Sendable, Hashable {
        /// Copying or moving: counts bytes.
        case copying
        /// Extracting an archive: counts entries.
        case extracting
        /// Compressing to an archive: counts entries.
        case compressing
    }

    /// The bytes copied or entries handled so far.
    public var completedBytes: Int64
    /// All bytes the transfer copies, a move within a volume none, or all
    /// entries of an archive; 0 while they are not yet counted.
    public var totalBytes: Int64
    /// The file being handled now, or `nil` between items.
    public var currentName: String?
    /// What the operation does.
    public var kind: Kind

    /// Creates a progress value.
    public init(
        completedBytes: Int64, totalBytes: Int64, currentName: String? = nil, kind: Kind = .copying
    ) {
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
        self.currentName = currentName
        self.kind = kind
    }

    /// The part done, from 0 to 1. A transfer that copies nothing is done; an
    /// archive operation without a total has not started counting.
    public var fraction: Double {
        guard totalBytes != 0 else { return kind == .copying ? 1 : 0 }
        return min(1, Double(completedBytes) / Double(totalBytes))
    }
}

/// Puts an item into a folder under a name: a move or a rename.
public struct Relocation: Sendable, Hashable {
    /// The item to move.
    public var item: FileItem.ID
    /// The folder it goes into.
    public var folder: FileItem.ID
    /// The name it gets there.
    public var name: String

    /// Creates a relocation.
    public init(item: FileItem.ID, folder: FileItem.ID, name: String) {
        self.item = item
        self.folder = folder
        self.name = name
    }
}

/// An item in the Trash, with where it came from.
public struct TrashedItem: Sendable, Hashable {
    /// The item's identity in the Trash.
    public var trashID: FileItem.ID
    /// Its identity before it was moved to the Trash.
    public var originalID: FileItem.ID

    /// Creates a trashed item.
    public init(trashID: FileItem.ID, originalID: FileItem.ID) {
        self.trashID = trashID
        self.originalID = originalID
    }
}

/// The inverse of an operation, which undoes it (ADR 0018).
public indirect enum UndoRecord: Sendable, Hashable {
    /// Nothing to undo.
    case none
    /// Move items back where they came from, under their old names.
    case relocate([Relocation])
    /// Move items that the operation created to the Trash.
    case trash([FileItem.ID])
    /// Put items back from the Trash.
    case restore([TrashedItem])
    /// Undo several steps, in this order.
    case sequence([UndoRecord])
}

/// What an operation did: the items it produced, and how to undo it.
public struct OperationResult: Sendable {
    /// The items after the operation, under their new identities.
    public var items: [FileItem]
    /// The inverse of the operation.
    public var undo: UndoRecord
    /// Whether the resolver stopped the operation before every item was handled.
    public var stopped: Bool

    /// Creates a result.
    public init(items: [FileItem], undo: UndoRecord, stopped: Bool = false) {
        self.items = items
        self.undo = undo
        self.stopped = stopped
    }
}
