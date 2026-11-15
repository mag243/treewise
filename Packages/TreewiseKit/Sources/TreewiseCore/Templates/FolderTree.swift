import Foundation

/// A tree of folder names: a folder and the folders in it, at every depth, without files
/// (ADR 0091). A template's tree may hold `{year}` in its names; a tree to make has it filled in.
///
/// Invariant: `folders` are ordered by name as Finder orders them.
public struct FolderTree: Codable, Hashable, Sendable {
    /// The most folders a tree may hold, its root included, so a template cannot flood a disk.
    public static let mostFolders = 1000
    /// The most levels a tree may have, its root the first.
    public static let mostLevels = 32
    /// The placeholder for the year, as in a name pattern (ADR 0090).
    public static let yearField = "{year}"

    /// Why a tree cannot be made.
    public enum Problem: Error, Hashable, Sendable {
        /// A name no folder can have: empty, `.`, `..`, or with `/` or `:`.
        case invalidName(String)
        /// A name that starts with a dot, which Finder hides.
        case hiddenName(String)
        /// Two folders in one folder whose names the file system treats as the same.
        case sameName(String)
        /// More than `mostFolders` folders.
        case tooManyFolders
        /// More than `mostLevels` levels.
        case tooDeep
        /// A name holds a template's field with a format it does not take, as `{date:qq}`
        /// (ADR 0096).
        case invalidFormat(String)
        /// A name below a template's root holds `{seq}`, which only the root may (ADR 0096).
        case numberBelowTop(String)
        /// A folder would move into itself or a folder in it (ADR 0095).
        case intoItself
        /// A template's root holds a repeat, which only a folder below it may (ADR 0100).
        case repeatAtTop(String)
        /// A name holds a repeat inside a repeating folder, or two repeats (ADR 0100).
        case repeatInRepeat(String)
    }

    /// The folder's name.
    public let name: String
    /// The folders in it, ordered by name.
    public let folders: [FolderTree]
    /// The name settings a folder made from it gets, in a template (ADR 0101).
    public let names: FolderNameSettings?

    /// A folder with the folders in it, which it orders by name, and its name settings.
    public init(name: String, folders: [FolderTree] = [], names: FolderNameSettings? = nil) {
        self.name = name
        self.folders = folders.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        self.names = names
    }

    /// A tree from a file or from an add-on, ordered as any other; a folder without
    /// `folders` holds none, and one without `names` has no name settings.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            folders: try container.decodeIfPresent([FolderTree].self, forKey: .folders) ?? [],
            names: try container.decodeIfPresent(FolderNameSettings.self, forKey: .names))
    }

    /// Whether an item in a folder that is saved as a template counts as one of its folders:
    /// a plain folder that is not hidden. Files, packages and aliases are left out.
    public static func keeps(_ item: FileItem) -> Bool {
        item.kind == .folder && !item.isHidden
    }

    /// Checks that every folder of the tree can be made where it is placed: names only,
    /// relative to the folder the tree is made in, none hidden or twice in one folder, and
    /// within `mostFolders` and `mostLevels`.
    public func check() throws(Problem) {
        var count = 0
        try check(level: 1, inRepeat: false, count: &count) { folder, _, _ throws(Problem) in
            guard FileName.isValid(folder.name) else { throw .invalidName(folder.name) }
            return false
        }
    }

    /// Checks the tree of a template as `check()` does, with its fields (ADR 0096): they must
    /// read, `{seq}` only in the root, a repeat only below it and never in another (ADR 0100),
    /// and the text around them a name can hold, since a `:` in a field is no path separator.
    /// Its names are checked once more when filled in. Each name is read once.
    public func checkTemplate() throws(Problem) {
        var count = 0
        try check(level: 1, inRepeat: false, count: &count, folder: Self.checkFields)
    }

    /// Checks one folder's name with its fields, and says whether the folder repeats.
    private static func checkFields(_ folder: FolderTree, isRoot: Bool, inRepeat: Bool)
        throws(Problem) -> Bool
    {
        let read = try FolderNameFields(folder.name)
        guard FileName.isValid(read.plainText) else { throw .invalidName(folder.name) }
        if !isRoot, read.fields.contains(.number) { throw .numberBelowTop(folder.name) }
        let repeats = read.repeats.count
        if isRoot, repeats > 0 { throw .repeatAtTop(folder.name) }
        guard repeats <= 1, !inRepeat || repeats == 0 else { throw .repeatInRepeat(folder.name) }
        return repeats > 0
    }

    /// Walks the tree once: the depth and the count, each folder's own check, its name not
    /// hidden, and no name twice in one folder. `folder` gets the folder, whether it is the
    /// root and whether a repeat is above it, and says whether the folder repeats.
    private func check(
        level: Int, inRepeat: Bool, count: inout Int,
        folder check: (FolderTree, Bool, Bool) throws(Problem) -> Bool
    ) throws(Problem) {
        guard level <= Self.mostLevels else { throw .tooDeep }
        count += 1
        guard count <= Self.mostFolders else { throw .tooManyFolders }
        let repeats = try check(self, level == 1, inRepeat)
        guard !name.hasPrefix(".") else { throw .hiddenName(name) }
        var seen = Set<String>()
        for folder in folders {
            guard seen.insert(ConflictResolver.comparisonKey(folder.name)).inserted else {
                throw .sameName(folder.name)
            }
            try folder.check(
                level: level + 1, inRepeat: inRepeat || repeats, count: &count, folder: check)
        }
    }
}
