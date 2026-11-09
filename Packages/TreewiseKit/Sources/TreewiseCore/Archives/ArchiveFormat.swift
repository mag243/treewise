/// A format Treewise can compress to (ADR 0074).
public enum ArchiveFormat: Sendable, Hashable, CaseIterable {
    /// A zip file, the default.
    case zip
    /// A 7-Zip file.
    case sevenZip
    /// A tar file compressed with gzip.
    case tarGzip

    /// The extension of an archive in this format, without its leading dot.
    public var pathExtension: String {
        switch self {
        case .zip: "zip"
        case .sevenZip: "7z"
        case .tarGzip: "tar.gz"
        }
    }
}
