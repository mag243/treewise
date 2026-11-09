import Foundation

/// How much of an archive is extracted for a preview (ADR 0076).
public enum ArchiveCachePolicy {
    /// The most an archive extracts as a whole for a preview, in bytes.
    public static let wholeArchiveLimit: Int64 = 2_000_000_000
    private static let directAccessExtension = "zip"

    /// Whether a preview extracts all of an archive. A zip reaches each entry
    /// directly. In another format reaching an entry can read much of the
    /// archive, so one pass serves all later previews, when the result is not
    /// too large and fits.
    ///
    /// - Parameter freeBytes: the free space, or `nil` when it is unknown.
    public static func extractsWhole(
        archiveName: String, totalBytes: Int64, freeBytes: Int64?
    ) -> Bool {
        guard (archiveName as NSString).pathExtension.lowercased() != directAccessExtension,
            let freeBytes
        else { return false }
        return totalBytes <= wholeArchiveLimit && totalBytes < freeBytes
    }
}
