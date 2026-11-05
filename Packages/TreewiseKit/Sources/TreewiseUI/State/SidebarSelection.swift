/// Which sidebar row is selected for the current folder, when several rows
/// stand for it: a folder can be a favorite and also be open in the tree.
public enum SidebarSelection {
    /// A visible row that stands for the current folder.
    public struct Candidate: Equatable, Sendable {
        public let row: Int
        /// Whether the row is in Favorites rather than in the tree.
        public let isFavorite: Bool

        public init(row: Int, isFavorite: Bool) {
            self.row = row
            self.isFavorite = isFavorite
        }
    }

    /// The row to select: the selected one if it stands for the current folder,
    /// so a clicked row keeps the selection; else the first row in the tree;
    /// else the first favorite; `nil` when no row stands for the folder.
    public static func row(among candidates: [Candidate], selected: Int?) -> Int? {
        if let selected, candidates.contains(where: { $0.row == selected }) {
            return selected
        }
        return candidates.first { !$0.isFavorite }?.row ?? candidates.first?.row
    }
}
