import Foundation

/// The names in a folder without their extensions, split once for every file a review
/// proposes names for there, not once per file.
public struct FolderNames: Hashable, Sendable {
    private let names: [String]
    private let stems: [String]

    /// The folder's names, with their extensions.
    public init(_ names: [String]) {
        self.names = names
        self.stems = names.map(ProposedName.stem(of:))
    }

    /// The stems of every name but `name`: the names around a file.
    public func stems(besides name: String) -> [String] {
        zip(names, stems).compactMap { $0.0 == name ? nil : $0.1 }
    }
}
