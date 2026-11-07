import Foundation

/// Which folder settings Treewise drops on its own (ADR 0072): those of a folder that has
/// not been seen for a while on a disk that is attached. A folder on a detached disk, or
/// one that may have moved while Treewise did not run, keeps its settings for that while.
public enum FolderSettingsCleanup {
    /// How long a folder may go unseen on an attached disk before its settings go.
    public static let maximumUnseen: TimeInterval = 30 * 24 * 60 * 60
    /// The folder under which macOS mounts every disk but the startup disk.
    private static let volumesFolder = "/Volumes"
    private static let startupDisk = "/"

    /// What to do with the settings of one folder.
    public enum Verdict: Hashable, Sendable {
        /// The folder is at its path: it is seen now.
        case seen
        /// It is not, but its settings stay, as they are and with their date.
        case keep
        /// Its settings go.
        case drop
    }

    /// Decides for the settings of one folder.
    ///
    /// - Parameters:
    ///   - isThere: Whether the folder is at its recorded path.
    ///   - diskIsAttached: Whether the disk of that path is attached.
    ///   - lastSeen: When the folder was last seen.
    ///   - now: The time of the check.
    public static func verdict(
        isThere: Bool, diskIsAttached: Bool, lastSeen: Date, now: Date
    ) -> Verdict {
        if isThere { return .seen }
        guard diskIsAttached, now.timeIntervalSince(lastSeen) > maximumUnseen else {
            return .keep
        }
        return .drop
    }

    /// The folder a path's disk is mounted at: `/Volumes/<name>` for a path under it, and
    /// the startup disk `/` for every other path.
    public static func disk(of path: String) -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 2, "/" + parts[0] == volumesFolder else { return startupDisk }
        return volumesFolder + "/" + parts[1]
    }
}
