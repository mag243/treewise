import Foundation

/// Whether Treewise offers at launch to move itself to Applications, and where
/// it goes (ADR 0034). An app outside Applications may run from a read-only
/// translocated copy, which Sparkle cannot update. Paths are compared as text:
/// case-insensitively and Unicode-normalised, as APFS does, after `.` and `..`
/// are resolved; the disk is never read.
public enum ApplicationsMove {
    /// The two folders macOS treats as Applications.
    public struct Folders: Sendable, Equatable {
        /// `/Applications`.
        public let system: String
        /// `~/Applications`, for when the system folder is not writable.
        public let user: String

        public init(system: String, user: String) {
            self.system = system
            self.user = user
        }
    }

    /// Returns whether to ask: the app is not inside either Applications
    /// folder, or one of their subfolders, and the user has not declined before.
    public static func shouldOffer(appPath: String, folders: Folders, declined: Bool) -> Bool {
        guard !declined else { return false }
        let app = components(of: appPath)
        return ![folders.system, folders.user].contains { folder in
            let parent = components(of: folder)
            return app.count > parent.count && Array(app.prefix(parent.count)) == parent
        }
    }

    /// Returns the folder to copy the app into: the system folder when it is
    /// writable, else the user's.
    public static func destinationFolder(_ folders: Folders, systemIsWritable: Bool) -> String {
        systemIsWritable ? folders.system : folders.user
    }

    /// The path's components with `.` and `..` resolved, lowercased and
    /// normalised, so equal paths compare equal.
    private static func components(of path: String) -> [String] {
        var result: [String] = []
        for part in path.split(separator: "/") {
            switch part {
            case ".": continue
            case "..": _ = result.popLast()
            default: result.append(part.precomposedStringWithCanonicalMapping.lowercased())
            }
        }
        return result
    }
}
