#if os(macOS)
    import TreewiseCore

    /// What tar's complaints about an archive mean (ADR 0074).
    enum TarFailure {
        /// The words libarchive uses when an entry needs a password, for zip,
        /// 7z and rar alike.
        private static let passwordWords = ["passphrase", "password", "encrypt", "crypto"]

        /// The error for a failed extraction.
        ///
        /// A complaint names the entry first, which may be a file called
        /// `password.txt`, so only the text after it counts.
        static func extractionError(
            _ failures: [String], archive: FileItem.ID, folder: FileItem.ID
        ) -> FileSystemError {
            let reasons = failures.map(reason)
            func mention(_ words: [String]) -> Bool {
                reasons.contains { reason in words.contains { reason.contains($0) } }
            }
            if mention(passwordWords) { return .archivePasswordProtected(archive) }
            if mention(["unrecognized archive format"]) { return .archiveFormatUnknown(archive) }
            if mention(["no space left"]) { return .notEnoughSpace(folder) }
            if mention(["failed to open"]) { return .notReadable(archive) }
            if mention(["permission denied", "read-only file system"]) {
                return .notWritable(folder)
            }
            return .archiveDamaged(archive)
        }

        /// The error for a failed compression.
        static func compressionError(_ failures: [String], folder: FileItem.ID) -> FileSystemError {
            if failures.contains(where: { reason($0).contains("no space left") }) {
                return .notEnoughSpace(folder)
            }
            return .unexpected(failures.first ?? "tar")
        }

        private static func reason(_ failure: String) -> String {
            guard let separator = failure.range(of: ": ") else { return failure.lowercased() }
            return failure[separator.upperBound...].lowercased()
        }
    }
#endif
