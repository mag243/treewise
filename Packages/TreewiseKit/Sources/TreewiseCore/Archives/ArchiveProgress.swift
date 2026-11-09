/// How far extracting or compressing is, in entries: `tar` reports no bytes
/// (ADR 0074).
public struct ArchiveProgress: Sendable, Hashable {
    /// The entries handled so far.
    public var completedEntries: Int
    /// All entries the operation handles.
    public var totalEntries: Int
    /// The path of the entry handled last, inside the archive.
    public var currentName: String?

    /// Creates a progress value.
    public init(completedEntries: Int, totalEntries: Int, currentName: String? = nil) {
        self.completedEntries = completedEntries
        self.totalEntries = totalEntries
        self.currentName = currentName
    }

    /// The part done, from 0 to 1; 1 when there are no entries.
    public var fraction: Double {
        totalEntries == 0 ? 1 : min(1, Double(completedEntries) / Double(totalEntries))
    }
}
