import SwiftUI
import TreewiseCore
import TreewiseUI

/// The folder's items: a table with headings and the columns the user chose and sized
/// (ADR 0125), its rows in a UIKit collection view (ADR 0116), or narrow rows when the name
/// would have too little room.
struct FolderTable: View {
    let browser: BrowserState
    let items: [FileItem]
    /// The folder shown, which takes a drop on a file's row or beside the rows.
    let folder: FileItem?
    let settings: BrowserSettings
    let actions: ItemActions
    let drops: ItemDrops
    /// Whether the screen is compact, where the folder is always narrow.
    let isCompact: Bool
    /// Whether the user is selecting (ADR 0124).
    @Binding var isSelecting: Bool

    @State private var width: CGFloat = 0

    /// The chosen columns that fit beside a name of `minimumNameWidth` (ADR 0125).
    private var layout: TableColumnLayout {
        settings.tableColumns.fitted(
            into: Double(FolderTableColumn.roomForColumns(in: width)),
            spacing: Double(FolderTableColumn.spacing))
    }

    /// Whether the rows are narrow: on a compact screen, and where not even the column
    /// that gives way last fits beside the name.
    private var isNarrow: Bool {
        isCompact || FolderTableColumn.roomForColumns(in: width) < 0
            || (layout.shown.isEmpty && !settings.tableColumns.shown.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isNarrow {
                FolderTableHeadings(
                    browser: browser, settings: settings, layout: layout,
                    spareWidth: max(width - FolderTableColumn.minimumTableWidth(for: layout), 0))
                Divider()
            }
            FolderCollection(
                browser: browser, undoManager: actions.undoManager, isNarrow: isNarrow,
                layout: layout, items: items, folder: folder, settings: settings, actions: actions,
                drops: drops,
                isSelecting: isSelecting, beginSelecting: { isSelecting = true })
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            width = $0
        }
    }
}

/// A column of the table: the name, which takes the room the others leave, or one of the
/// columns the user chooses and sizes (ADR 0125).
enum FolderTableColumn: Hashable {
    case name
    case detail(FolderColumn)

    /// The margin before the first column and after the last.
    static let margin: CGFloat = 20
    /// The room between two columns, with the line between their headings in its middle:
    /// enough on either side that a heading does not touch it, as in Files.
    static let spacing: CGFloat = 20
    /// The narrowest the name column may be before the folder shows its narrow rows.
    static let minimumNameWidth: CGFloat = 200
    /// The room the headings' column menu takes after the last column, which the rows keep
    /// free too, so that their columns stay under the headings.
    static let menuWidth: CGFloat = 32

    /// The columns `layout` shows, the name first.
    static func shown(in layout: TableColumnLayout) -> [FolderTableColumn] {
        [.name] + layout.shown.map(FolderTableColumn.detail)
    }

    /// The room a table `width` wide leaves for the columns beside a name of
    /// `minimumNameWidth`, each taking its width and `spacing`.
    static func roomForColumns(in width: CGFloat) -> CGFloat {
        width - margin * 2 - menuWidth - spacing - minimumNameWidth
    }

    /// The width the columns of `layout` need, with a name of `minimumNameWidth`.
    static func minimumTableWidth(for layout: TableColumnLayout) -> CGFloat {
        let columns = shown(in: layout)
        let fixed = columns.compactMap { $0.width(in: layout) }.reduce(0, +)
        return margin * 2 + spacing * CGFloat(columns.count) + menuWidth + fixed
            + minimumNameWidth
    }

    var sortColumn: SortColumn {
        switch self {
        case .name: .name
        case .detail(let column): column.sortColumn
        }
    }

    var title: String {
        switch self {
        case .name: String(localized: "Name")
        case .detail(let column): Self.title(of: column)
        }
    }

    static func title(of column: FolderColumn) -> String {
        switch column {
        case .dateModified: String(localized: "Date Modified")
        case .dateCreated: String(localized: "Date Created")
        case .dateAdded: String(localized: "Date Added")
        case .size: String(localized: "Size")
        case .kind: String(localized: "Kind")
        }
    }

    /// A name for the column that does not change with the language, for the UI tests.
    var identifier: String {
        switch self {
        case .name: "name"
        case .detail(let column): column.rawValue
        }
    }

    /// The column's width in `layout`; `nil` for the name, which takes the rest.
    func width(in layout: TableColumnLayout) -> CGFloat? {
        switch self {
        case .name: nil
        case .detail(let column): CGFloat(layout.width(of: column))
        }
    }
}

extension View {
    /// Sets a view in a column of the table, its width as its heading's.
    func inColumn(_ column: FolderTableColumn, of layout: TableColumnLayout) -> some View {
        let width = column.width(in: layout)
        return frame(maxWidth: width ?? .infinity, alignment: .leading)
            .frame(width: width, alignment: .leading)
    }
}

/// A row of the table: the item's name with its icon, cut in the middle so that its end
/// stays in sight, and the columns the user chose.
struct FolderTableRow: View {
    let item: FileItem
    let showsExtensions: Bool
    let layout: TableColumnLayout

    private let formats = ItemFormats()

    var body: some View {
        HStack(spacing: FolderTableColumn.spacing) {
            Label {
                HStack {
                    Text(DisplayName.text(for: item, showsExtension: showsExtensions))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    OnlyOnlineMark(item: item)
                }
            } icon: {
                Image(systemName: ItemSymbol.name(for: item))
                    .foregroundStyle(item.isContainer ? Color.accentColor : .secondary)
            }
            .inColumn(.name, of: layout)
            ForEach(layout.shown, id: \.self) { column in
                Text(text(of: column)).foregroundStyle(.secondary).lineLimit(1)
                    .inColumn(.detail(column), of: layout)
            }
            Color.clear.frame(width: FolderTableColumn.menuWidth)
        }
    }

    private func text(of column: FolderColumn) -> String {
        switch column {
        case .dateModified: formats.date(of: item)
        case .dateCreated: formats.date(item.created)
        case .dateAdded: formats.date(item.added)
        case .size: formats.size(of: item)
        case .kind: formats.kind(of: item)
        }
    }
}
