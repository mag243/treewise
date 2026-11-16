/// Why items may not be dropped on a target (PLAN.md §4.1), to tell the user when a drop
/// is checked only as it lands, as in the iPad's table (ADR 0047, amended 2026-11-16).
public enum DropRefusal: Sendable, Hashable {
    /// The target takes no items: a file, a package, This Mac.
    case notAFolder
    /// A folder would go into itself or a folder inside it.
    case intoItself
    /// The items would move into the folder they are already in.
    case alreadyThere
    /// An item cannot be moved or copied, such as a volume.
    case notMovable
    /// The target is inside an archive that cannot be changed (ADR 0076).
    case archiveReadOnly
}
