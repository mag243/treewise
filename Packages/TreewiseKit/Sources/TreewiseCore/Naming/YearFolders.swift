/// Folders kept per year (ADR 0090): the year in a folder's path, and the same folder a year
/// before it.
public enum YearFolders {
    /// The years a folder of its own counts as one.
    public static let years = 1900...2099
    private static let yearDigits = 4

    /// The year a name is, written as four ASCII digits within `years`, or nil for any
    /// other name, as `Tax 2026` or `２０２６`.
    public static func year(named name: some StringProtocol) -> Int? {
        guard name.count == yearDigits, name.allSatisfy({ $0.isASCII && $0.isNumber }),
            let year = Int(name), years.contains(year)
        else { return nil }
        return year
    }

    /// The year of a folder: its nearest path component that is a year, or nil without one.
    /// A place inside an archive has none, and a year inside a name, as `Tax 2026`, is no year.
    public static func year(of folder: FileItem.ID) -> Int? {
        yearComponent(of: folder)?.year
    }

    /// The year of a year's own folder, one whose name is the year, as `…/2026`; nil for any
    /// other folder, also one below it (ADR 0094, ADR 0102).
    public static func ownYear(of folder: FileItem.ID) -> Int? {
        guard let (index, year) = yearComponent(of: folder) else { return nil }
        let parts = folder.rawValue.split(separator: "/", omittingEmptySubsequences: false)
        return index == parts.count - 1 ? year : nil
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

    /// The year's own folder a folder is in, its nearest, and the folder's path below it, as
    /// `["Q1", "Tax"]` for `…/2026/Q1/Tax`; nil for a year's own folder and a folder in no
    /// year (ADR 0139).
    public static func place(of folder: FileItem.ID) -> (year: FileItem.ID, path: [String])? {
        guard let (index, _) = yearComponent(of: folder) else { return nil }
        let parts = folder.rawValue.split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        guard index < parts.count - 1 else { return nil }
        return (
            FileItem.ID(parts[...index].joined(separator: "/")), Array(parts[(index + 1)...])
        )
    }

    private static func yearComponent(of folder: FileItem.ID) -> (index: Int, year: Int)? {
        guard !folder.isInsideArchive else { return nil }
        let parts = folder.rawValue.split(separator: "/", omittingEmptySubsequences: false)
        for index in parts.indices.reversed() {
            guard let year = year(named: parts[index]), years.contains(year - 1) else { continue }
            return (index, year)
        }
        return nil
    }
}
