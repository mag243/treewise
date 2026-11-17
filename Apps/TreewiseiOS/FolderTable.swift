import SwiftUI
import TreewiseCore
import TreewiseUI

/// The folder as a table with the Mac's columns (ADR 0116): headings in SwiftUI that sort
/// through `BrowserState`, so folders stay first and names compare as on the Mac (PLAN.md §4),
/// above rows in a UIKit collection view, which take drops on their folders (ADR 0047).
/// Where the folder is narrower than the columns need, as on a compact screen or an 11-inch
/// iPad in portrait beside the sidebar, the headings go and each row shows the name with the
/// date and size beneath it.
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

    @State private var width: CGFloat = 0

    private var isNarrow: Bool {
        isCompact || width < FolderTableColumn.minimumTableWidth
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isNarrow {
                FolderTableHeadings(browser: browser)
                Divider()
            }
            FolderCollection(
                browser: browser, undoManager: actions.undoManager, isNarrow: isNarrow,
                items: items, folder: folder, settings: settings, actions: actions, drops: drops)
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            width = $0
        }
    }
}

/// The table's columns: their headings, what they sort by and their widths, the name taking
/// the room the others leave.
enum FolderTableColumn: CaseIterable {
    case name, dateModified, size, kind

    /// The margin before the first column and after the last.
    static let margin: CGFloat = 20
    /// The room between two columns.
    static let spacing: CGFloat = 12
    /// The narrowest the name column may be before the folder shows its narrow rows.
    static let minimumNameWidth: CGFloat = 200

    /// The width the columns need, with a name of `minimumNameWidth`.
    static var minimumTableWidth: CGFloat {
        let fixed = allCases.compactMap(\.width).reduce(0, +)
        return margin * 2 + spacing * CGFloat(allCases.count - 1) + fixed + minimumNameWidth
    }

    var sortColumn: SortColumn {
        switch self {
        case .name: .name
        case .dateModified: .dateModified
        case .size: .size
        case .kind: .kind
        }
    }

    var title: String {
        switch self {
        case .name: String(localized: "Name")
        case .dateModified: String(localized: "Date Modified")
        case .size: String(localized: "Size")
        case .kind: String(localized: "Kind")
        }
    }

    /// The column's width; `nil` for the name, which takes the rest.
    var width: CGFloat? {
        switch self {
        case .name: nil
        case .dateModified: 240
        case .size: 110
        case .kind: 240
        }
    }
}

extension View {
    /// Sets a view in a column of the table, its width as its heading's.
    func inColumn(_ column: FolderTableColumn) -> some View {
        frame(maxWidth: column.width ?? .infinity, alignment: .leading)
            .frame(width: column.width, alignment: .leading)
    }
}

/// The table's headings: tapping one sorts by its column, tapping it again turns the order
/// round, as on the Mac.
private struct FolderTableHeadings: View {
    /// The room above and below the headings.
    private static let padding: CGFloat = 10

    let browser: BrowserState

    var body: some View {
        HStack(spacing: FolderTableColumn.spacing) {
            ForEach(FolderTableColumn.allCases, id: \.self) { column in
                Button {
                    browser.sort(by: column.sortColumn)
                } label: {
                    HStack(spacing: 4) {
                        Text(column.title).fontWeight(.semibold)
                        if browser.sort.column == column.sortColumn {
                            Image(
                                systemName: browser.sort.ascending ? "chevron.up" : "chevron.down"
                            )
                            .font(.caption)
                        }
                    }
                }
                .accessibilityLabel(Text(column.title))
                .inColumn(column)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, FolderTableColumn.margin)
        .padding(.vertical, Self.padding)
    }
}

/// A row of the table: the item's name with its icon, its date, size and kind.
struct FolderTableRow: View {
    let item: FileItem
    let showsExtensions: Bool

    private let formats = ItemFormats()

    var body: some View {
        HStack(spacing: FolderTableColumn.spacing) {
            Label {
                HStack {
                    Text(DisplayName.text(for: item, showsExtension: showsExtensions))
                        .lineLimit(1)
                    OnlyOnlineMark(item: item)
                }
            } icon: {
                Image(systemName: ItemSymbol.name(for: item))
                    .foregroundStyle(item.isContainer ? Color.accentColor : .secondary)
            }
            .inColumn(.name)
            Text(formats.date(of: item)).foregroundStyle(.secondary).inColumn(.dateModified)
            Text(formats.size(of: item)).foregroundStyle(.secondary).inColumn(.size)
            Text(formats.kind(of: item)).foregroundStyle(.secondary).lineLimit(1)
                .inColumn(.kind)
        }
    }
}
