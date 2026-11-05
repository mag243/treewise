import Foundation

/// A column of the list that items can be sorted by.
public enum SortColumn: Sendable, Hashable, CaseIterable {
    /// The item's name.
    case name
    /// When the item last changed.
    case dateModified
    /// The item's size in bytes.
    case size
    /// The item's kind as the Kind column shows it.
    case kind
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
    /// remaining tie, so equal items always land in the same order.
    public func sorted(_ items: [FileItem], kinds: KindFormatter) -> [FileItem] {
        items.sorted { first, second in
            if first.isContainer != second.isContainer { return first.isContainer }
            let order = columnOrder(first, second, kinds: kinds)
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
        case .size:
            compare(first.size ?? 0, second.size ?? 0)
        case .kind:
            kinds.string(for: first).localizedStandardCompare(kinds.string(for: second))
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
