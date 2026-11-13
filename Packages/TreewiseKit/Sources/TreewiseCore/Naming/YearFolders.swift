/// Folders kept per year (ADR 0090): the year in a folder's path, and the same folder a year
/// before it.
public enum YearFolders {
    /// The years a folder of its own counts as one.
    private static let years = 1900...2099
    private static let yearDigits = 4

    /// The year of a folder: its nearest path component that is a year, or nil without one.
    /// A place inside an archive has none, and a year inside a name, as `Tax 2026`, is no year.
    public static func year(of folder: FileItem.ID) -> Int? {
        yearComponent(of: folder)?.year
    }

    /// The folder at the same path with its nearest year one lower, as `…/2025/Tax` for
    /// `…/2026/Tax`, or nil when its path holds no year. Whether it exists is not checked.
    public static func folderBefore(_ folder: FileItem.ID) -> FileItem.ID? {
        guard let (index, year) = yearComponent(of: folder) else { return nil }
        var parts = folder.rawValue.split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        parts[index] = String(year - 1)
        return FileItem.ID(parts.joined(separator: "/"))
    }

    private static func yearComponent(of folder: FileItem.ID) -> (index: Int, year: Int)? {
        guard !folder.isInsideArchive else { return nil }
        let parts = folder.rawValue.split(separator: "/", omittingEmptySubsequences: false)
        for index in parts.indices.reversed() {
            let part = parts[index]
            guard part.count == yearDigits, part.allSatisfy({ $0.isASCII && $0.isNumber }),
                let year = Int(part), years.contains(year), years.contains(year - 1)
            else { continue }
            return (index, year)
        }
        return nil
    }
}
