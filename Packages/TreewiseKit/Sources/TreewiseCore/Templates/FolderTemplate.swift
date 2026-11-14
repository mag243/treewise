import Foundation

/// A folder structure template: a name and the tree of folders it makes, whose names may
/// hold fields (ADR 0091, ADR 0096).
public struct FolderTemplate: Codable, Hashable, Sendable, Identifiable {
    /// A stable id, which a folder's settings name it by, so a rename keeps them
    /// (ADR 0097).
    public let id: String
    /// The name the user gave it, as listed in New Folders from Template.
    public var name: String
    /// The folders it makes, its root made in the folder chosen.
    public var root: FolderTree

    /// A template of `root` named `name`, with a new id unless one is given.
    public init(id: String = UUID().uuidString, name: String, root: FolderTree) {
        self.id = id
        self.name = name
        self.root = root
    }

    /// Whether making it asks for a year.
    public var hasYear: Bool { root.hasYear }

    /// Whether its root is a year's folder, `{year}`, as a template that ADR 0094 offers
    /// in an empty year's folder.
    public var isRootedAtYear: Bool { root.name == FolderTree.yearField }

    /// The year of a folder named `name` that this template fills itself when it is made in
    /// it, rather than making its root inside (ADR 0095): a template rooted at `{year}`, in a
    /// folder named as a year from 1900 to 2099. Nil when the root is made inside.
    public func yearOfFolderItFills(named name: String) -> Int? {
        guard isRootedAtYear, name.count == Self.yearDigits,
            name.allSatisfy({ $0.isASCII && $0.isNumber }), let year = Int(name),
            Self.years.contains(year)
        else { return nil }
        return year
    }

    private static let yearDigits = 4
    private static let years = 1900...2099
}
