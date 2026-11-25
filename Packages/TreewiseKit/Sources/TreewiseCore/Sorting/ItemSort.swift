import Foundation

/// A column of the list that items can be sorted by.
public enum SortColumn: String, Sendable, Hashable, CaseIterable {
    /// The item's name.
    case name
    /// When the item last changed.
    case dateModified
    /// When the item was made (ADR 0127).
    case dateCreated
    /// When the item came into its folder (ADR 0127).
    case dateAdded
    /// The item's size in bytes.
    case size
    /// The item's kind as the Kind column shows it.
    case kind
    /// The item's state in its git repository, as the Git column shows it (ADR 0149).
    case git
}

/// How the list is sorted: folders always first, then by a column, ties by
/// name (PLAN.md §4.4).
public struct ItemSort: Sendable, Hashable {
    /// The column to sort by.
    public var column: SortColumn
    /// Whether the column sorts from small to large.
    public var ascending: Bool

    /// Creates a sort by a column and direction; by name, ascending, by default.
    public init(column: SortColumn = .name, ascending: Bool = true) {
        self.column = column
        self.ascending = ascending
    }

    /// The sort after clicking a column header: the same column flips its
    /// direction, another column sorts ascending.
    public func selecting(_ column: SortColumn) -> ItemSort {
        column == self.column
            ? ItemSort(column: column, ascending: !ascending) : ItemSort(column: column)
    }

    /// Returns the items in order. Containers come before other items in either
    /// direction; within each group the column decides, then the name, compared
    /// as Finder does (`IMG_2` before `IMG_10`); the identity breaks any
    /// remaining tie, so equal items always land in the same order. By the Git column,
    /// `gitState` gives each item's state: a conflict first, then modified, new, ignored
    /// and unchanged.
    public func sorted(
        _ items: [FileItem], kinds: KindFormatter,
        gitState: (FileItem) -> GitItemState? = { _ in nil }
    ) -> [FileItem] {
        items.sorted { first, second in
            if first.isContainer != second.isContainer { return first.isContainer }
            let order =
                (column == .git
                ? compare(Self.gitRank(gitState(first)), Self.gitRank(gitState(second)))
                : columnOrder(first, second, kinds: kinds))
                .then(first.name.localizedStandardCompare(second.name))
            if order != .orderedSame {
                return ascending ? order == .orderedAscending : order == .orderedDescending
            }
            return first.id.rawValue < second.id.rawValue
        }
    }

    private func columnOrder(
        _ first: FileItem, _ second: FileItem, kinds: KindFormatter
    ) -> ComparisonResult {
        switch column {
        case .name:
            .orderedSame
        case .dateModified:
            compare(first.modified ?? .distantPast, second.modified ?? .distantPast)
        case .dateCreated:
            compare(first.created ?? .distantPast, second.created ?? .distantPast)
        case .dateAdded:
            compare(first.added ?? .distantPast, second.added ?? .distantPast)
        case .size:
            compare(first.size ?? 0, second.size ?? 0)
        case .kind:
            kinds.string(for: first).localizedStandardCompare(kinds.string(for: second))
        case .git:
            .orderedSame
        }
    }

    /// Where a git state sorts, what needs attention first.
    private static func gitRank(_ state: GitItemState?) -> Int {
        switch state {
        case .conflict: 0
        case .modified: 1
        case .new: 2
        case .ignored: 3
        case nil: 4
        }
    }

    private func compare<Value: Comparable>(_ first: Value, _ second: Value) -> ComparisonResult {
        first < second ? .orderedAscending : (first > second ? .orderedDescending : .orderedSame)
    }
}

extension ComparisonResult {
    /// This result, or `next` when this one is a tie.
    fileprivate func then(_ next: @autoclosure () -> ComparisonResult) -> ComparisonResult {
        self == .orderedSame ? next() : self
    }
}
