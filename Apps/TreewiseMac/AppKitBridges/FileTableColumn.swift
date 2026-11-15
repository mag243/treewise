import AppKit
import TreewiseCore

/// The list's columns, in order.
enum FileTableColumn: String, CaseIterable {
    case name, dateModified, size, kind

    /// The column's identifier in the table view.
    var identifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier(rawValue) }

    /// The sort column it stands for.
    var sortColumn: SortColumn {
        switch self {
        case .name: .name
        case .dateModified: .dateModified
        case .size: .size
        case .kind: .kind
        }
    }

    /// The header title.
    var title: String {
        switch self {
        case .name: String(localized: "Name", comment: "List column")
        case .dateModified: String(localized: "Date Modified", comment: "List column")
        case .size: String(localized: "Size", comment: "List column")
        case .kind: String(localized: "Kind", comment: "List column")
        }
    }

    /// The width the column starts with.
    var initialWidth: CGFloat {
        switch self {
        case .name: 280
        case .dateModified: 170
        case .size: 80
        case .kind: 150
        }
    }

    /// The narrowest the column gets when the list narrows: the name gives way first, as
    /// in Finder, then the list scrolls sideways.
    var minimumWidth: CGFloat {
        switch self {
        case .name: 120
        case .dateModified: 110
        case .size: 60
        case .kind: 80
        }
    }

    init(_ column: SortColumn) {
        self =
            switch column {
            case .name: .name
            case .dateModified: .dateModified
            case .size: .size
            case .kind: .kind
            }
    }

    /// Makes the table column, sortable by clicking its header.
    @MainActor
    func makeTableColumn() -> NSTableColumn {
        let column = NSTableColumn(identifier: identifier)
        column.title = title
        column.width = initialWidth
        column.minWidth = minimumWidth
        // Only the name follows the list's width; the others keep theirs until dragged.
        column.resizingMask =
            self == .name ? [.autoresizingMask, .userResizingMask] : .userResizingMask
        column.sortDescriptorPrototype = NSSortDescriptor(key: rawValue, ascending: true)
        if self == .size { column.headerCell.alignment = .right }
        return column
    }
}
