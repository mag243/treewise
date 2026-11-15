import SwiftUI
import TreewiseCore
import TreewiseUI

/// A table column's sort order, which the table hands back when a header is
/// tapped. It compares nothing itself: the browser sorts.
struct ColumnComparator: SortComparator {
    var column: SortColumn
    var order: SortOrder = .forward

    func compare(_ lhs: FileItem, _ rhs: FileItem) -> ComparisonResult {
        .orderedSame
    }
}
