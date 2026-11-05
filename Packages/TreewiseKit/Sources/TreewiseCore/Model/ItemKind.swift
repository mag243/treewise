/// What an item in the file system is, as far as Treewise's rules care.
public enum ItemKind: Sendable, Hashable, CaseIterable {
    /// A plain folder.
    case folder
    /// A regular file.
    case file
    /// A package such as an `.app`, which the system shows as a single file.
    case package
    /// A mounted volume: the startup disk or an external drive.
    case volume
    /// A cloud location such as iCloud Drive.
    case cloud
    /// This Mac: the location that holds the volumes (ADR 0044).
    case computer
    /// The user's home folder, a location of its own (ADR 0049).
    case home

    /// Whether the item opens like a folder, listing what is inside it.
    public var isContainer: Bool {
        switch self {
        case .folder, .volume, .cloud, .computer, .home: true
        case .file, .package: false
        }
    }

    /// Whether items can be dropped into, pasted into, or made in the item.
    /// This Mac opens like a folder but takes nothing: it lists the volumes.
    public var acceptsItems: Bool {
        switch self {
        case .folder, .volume, .cloud, .home: true
        case .computer, .file, .package: false
        }
    }

    /// Whether the item itself can be moved, copied, or cut.
    public var isMovable: Bool {
        switch self {
        case .folder, .file, .package: true
        case .volume, .cloud, .computer, .home: false
        }
    }

    /// Whether the item itself can be renamed or moved to the Trash. A cloud
    /// location cannot, as that would disconnect it from its service, nor can
    /// the home folder (ADR 0049).
    public var canBeRenamedOrTrashed: Bool {
        switch self {
        case .folder, .file, .package, .volume: true
        case .cloud, .computer, .home: false
        }
    }
}
