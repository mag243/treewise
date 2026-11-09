import Foundation

/// One file, folder, package, or location, as a file system provider reports it.
public struct FileItem: Identifiable, Hashable, Sendable {
    /// Identifies an item. Opaque to Core: a key in the in-memory fixture, a
    /// standardized path for the local file system (ADR 0015).
    public struct ID: Hashable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
        /// The provider's identifier of the item.
        public let rawValue: String

        /// Creates an identifier from the provider's raw value.
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        /// Creates an identifier from a string literal.
        public init(stringLiteral value: String) {
            self.init(value)
        }

        /// The raw value.
        public var description: String { rawValue }
    }

    /// The item's identity.
    public let id: ID
    /// The full name as the file system has it, extension included (`Notes.md`).
    public var name: String
    /// What the item is.
    public var kind: ItemKind
    /// The folder or location that contains the item; `nil` for a top-level location.
    public var parentID: ID?
    /// The volume the item lives on.
    public var volume: VolumeID
    /// When the item's contents last changed, if known.
    public var modified: Date?
    /// The size in bytes; `nil` for containers and when unknown.
    public var size: Int64?
    /// The human-readable kind from the provider (`PDF document`), if it has one.
    public var kindDescription: String?
    /// Whether the provider marks the item hidden: a name starting with a dot,
    /// or the hidden flag (ADR 0023).
    public var isHidden: Bool
    /// Whether the item is a volume that can be ejected (ADR 0044).
    public var isEjectable = false
    /// Whether the item is a file a cloud service keeps only online, which
    /// downloads when it is opened (ADR 0051).
    public var isOnlyOnline = false

    /// Creates an item.
    public init(
        id: ID,
        name: String,
        kind: ItemKind,
        parentID: ID? = nil,
        volume: VolumeID,
        modified: Date? = nil,
        size: Int64? = nil,
        kindDescription: String? = nil,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.parentID = parentID
        self.volume = volume
        self.modified = modified
        self.size = size
        self.kindDescription = kindDescription
        self.isHidden = isHidden
    }

    /// Whether the item opens like a folder.
    public var isContainer: Bool { kind.isContainer }

    /// Whether items can be dropped, pasted or made in this item. An archive
    /// takes nothing (ADR 0076).
    public var acceptsItems: Bool { kind.acceptsItems && !id.isInsideArchive }

    /// Whether this item can be copied, also out of an archive.
    public var isCopyable: Bool { kind.isMovable }

    /// Whether this item can be moved or cut, which would change an archive it is in.
    public var isMovable: Bool { kind.isMovable && !id.isInsideArchive }

    /// Whether this item can be renamed or moved to the Trash.
    public var canBeRenamedOrTrashed: Bool { kind.canBeRenamedOrTrashed && !id.isInsideArchive }
}
