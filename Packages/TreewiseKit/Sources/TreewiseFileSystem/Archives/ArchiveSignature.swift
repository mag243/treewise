#if os(macOS)
    import Foundation

    /// What tells that an archive on disk changed: its size and date (ADR 0076).
    struct ArchiveSignature: Hashable, Sendable {
        private let size: Int64
        private let seconds: Int
        private let nanoseconds: Int

        /// The signature as text, to keep with a version of the archive.
        var text: String { "\(size)-\(seconds)-\(nanoseconds)" }

        /// Reads the signature of the file at `path`, following a link, or
        /// returns `nil` when no regular file is there.
        init?(path: String) {
            var info = stat()
            guard stat(path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return nil }
            size = info.st_size
            seconds = info.st_mtimespec.tv_sec
            nanoseconds = info.st_mtimespec.tv_nsec
        }
    }
#endif
