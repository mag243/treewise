import SwiftUI
import TreewiseCore
import TreewiseUI

/// The folder as a table with the Mac's columns, on a wide screen. A column
/// header sorts through `BrowserState`, so folders stay first and names
/// compare as on the Mac (PLAN.md §4).
struct FolderTable: View {
    let browser: BrowserState
    let items: [FileItem]
    let settings: BrowserSettings
    let actions: ItemActions

    private let formats = ItemFormats()

    var body: some View {
        Table(items, selection: selection, sortOrder: sortOrder) {
            TableColumn("Name", sortUsing: ColumnComparator(column: .name)) { item in
                Label {
                    Text(DisplayName.text(for: item, showsExtension: settings.showsExtensions))
                } icon: {
                    Image(systemName: ItemSymbol.name(for: item))
                        .foregroundStyle(item.isContainer ? Color.accentColor : .secondary)
                }
            }
            TableColumn("Date Modified", sortUsing: ColumnComparator(column: .dateModified)) {
                Text(formats.date(of: $0)).foregroundStyle(.secondary)
            }
            TableColumn("Size", sortUsing: ColumnComparator(column: .size)) {
                Text(formats.size(of: $0)).foregroundStyle(.secondary)
            }
            TableColumn("Kind", sortUsing: ColumnComparator(column: .kind)) {
                Text(formats.kind(of: $0)).foregroundStyle(.secondary)
            }
        }
        .contextMenu(forSelectionType: FileItem.ID.self) { ids in
            ItemMenu(items: items.filter { ids.contains($0.id) }, actions: actions)
        } primaryAction: { ids in
            if let item = items.first(where: { ids.contains($0.id) }) { actions.open(item) }
        }
    }

    private var selection: Binding<Set<FileItem.ID>> {
        let tab = browser.layout.focusedPane.activeTabID
        return Binding(
            get: { browser.content(of: tab).selection },
            set: { browser.setSelection($0, in: tab) })
    }

    private var sortOrder: Binding<[ColumnComparator]> {
        Binding(
            get: {
                [
                    ColumnComparator(
                        column: browser.sort.column,
                        order: browser.sort.ascending ? .forward : .reverse)
                ]
            },
            set: { order in
                guard let first = order.first else { return }
                browser.sort(by: first.column, ascending: first.order == .forward)
            })
    }
}

/// A table column's sort order, which the table hands back when a header is
/// tapped. It compares nothing itself: the browser sorts.
struct ColumnComparator: SortComparator {
    var column: SortColumn
    var order: SortOrder = .forward

    func compare(_ lhs: FileItem, _ rhs: FileItem) -> ComparisonResult {
        .orderedSame
    }
}
