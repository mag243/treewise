import SwiftUI
import TreewiseCore
import TreewiseUI

/// The folder as a table with the Mac's columns, on a wide screen (ADR 0116): headings in
/// SwiftUI that sort through `BrowserState`, so folders stay first and names compare as on
/// the Mac (PLAN.md §4), above rows in a UIKit collection view, which take drops on their
/// folders (ADR 0047).
struct FolderTable: View {
    let browser: BrowserState
    let items: [FileItem]
    /// The folder shown, which takes a drop on a file's row or beside the rows.
    let folder: FileItem?
    let settings: BrowserSettings
    let actions: ItemActions
    let drops: ItemDrops

    var body: some View {
        VStack(spacing: 0) {
            FolderTableHeadings(browser: browser)
            Divider()
            FolderCollection(
                browser: browser, undoManager: actions.undoManager,
                items: items, folder: folder, settings: settings, actions: actions, drops: drops)
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
                Text(DisplayName.text(for: item, showsExtension: showsExtensions))
                    .lineLimit(1)
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
