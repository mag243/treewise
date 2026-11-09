/// Which names are archives, and the names of what extracting and compressing
/// make (ADR 0074).
public enum ArchiveNaming {
    /// The extensions of the formats whose trial on the system's `tar` passed,
    /// in lowercase.
    private static let archiveExtensions: Set<String> = [
        "zip", "tar", "tar.gz", "tgz", "tar.bz2", "tar.xz", "7z", "rar", "iso", "cpio", "xar",
    ]

    /// Whether an item is an archive Treewise can extract: a file whose
    /// extension, in any case, is one of the supported formats. A folder or a
    /// package with such a name is not an archive.
    public static func isArchive(name: String, kind: ItemKind) -> Bool {
        guard kind == .file else { return false }
        let (_, pathExtension) = ConflictResolver.split(name, kind: kind)
        return archiveExtensions.contains(pathExtension.dropFirst().lowercased())
    }

    /// The name of the folder an archive extracts to by default: the archive's
    /// name without its extension, so `Photos.zip` and `Photos.tar.gz` both give
    /// `Photos`. A name that is taken gets `copy`, as in every other conflict.
    ///
    /// Postcondition: the result matches none of `existing`.
    public static func extractionFolderName(
        for archiveName: String, among existing: some Sequence<String>
    ) -> String {
        let (base, _) = ConflictResolver.split(archiveName, kind: .file)
        return ConflictResolver.availableName(for: base, kind: .folder, among: existing)
    }

    /// The name of a new archive, after the item that was clicked: a folder
    /// keeps its whole name, any other item loses its extension. A name that is
    /// taken gets `copy` before the archive's extension.
    ///
    /// Postcondition: the result matches none of `existing`.
    public static func newArchiveName(
        after itemName: String, kind: ItemKind, format: ArchiveFormat,
        among existing: some Sequence<String>
    ) -> String {
        let (base, _) = ConflictResolver.split(itemName, kind: kind)
        return ConflictResolver.availableName(
            for: "\(base).\(format.pathExtension)", kind: .file, among: existing)
    }
}
