import SwiftUI
import TreewiseCore
import TreewiseUI

/// The folder as a table with the Mac's columns, on a wide screen. A column
/// header sorts through `BrowserState`, so folders stay first and names
/// compare as on the Mac (PLAN.md §4). A row is dragged as its item; its cells take drops,
/// checked as they land, and a drop on a file's row goes to the folder shown (ADR 0047,
/// amended 2026-11-16).
struct FolderTable: View {
    let browser: BrowserState
    let items: [FileItem]
    /// The folder shown, which takes a drop on a file's row or beside the rows.
    let folder: FileItem?
    let settings: BrowserSettings
    let actions: ItemActions
    let drops: ItemDrops

    private let formats = ItemFormats()
    private static let byDate = ColumnComparator(column: .dateModified)

    var body: some View {
        Table(of: FileItem.self, selection: selection, sortOrder: sortOrder) {
            TableColumn("Name", sortUsing: ColumnComparator(column: .name)) { item in
                cell(of: item) {
                    Label {
                        Text(DisplayName.text(for: item, showsExtension: settings.showsExtensions))
                    } icon: {
                        Image(systemName: ItemSymbol.name(for: item))
                            .foregroundStyle(item.isContainer ? Color.accentColor : .secondary)
                    }
                }
            }
            TableColumn("Date Modified", sortUsing: Self.byDate) { item in
                cell(of: item) { Text(formats.date(of: item)).foregroundStyle(.secondary) }
            }
            TableColumn("Size", sortUsing: ColumnComparator(column: .size)) { item in
                cell(of: item) { Text(formats.size(of: item)).foregroundStyle(.secondary) }
            }
            TableColumn("Kind", sortUsing: ColumnComparator(column: .kind)) { item in
                cell(of: item) { Text(formats.kind(of: item)).foregroundStyle(.secondary) }
            }
        } rows: {
            ForEach(items) { item in
                TableRow(item).itemProvider { drops.provider(for: item) }
            }
        }
        .contextMenu(forSelectionType: FileItem.ID.self) { ids in
            ItemMenu(items: items.filter { ids.contains($0.id) }, actions: actions)
        } primaryAction: { ids in
            if let item = items.first(where: { ids.contains($0.id) }) { actions.open(item) }
        }
    }

    /// A cell that takes drops across its width: on its folder, or for a file's row on the
    /// folder shown (PLAN.md §4.1), as the table itself takes none on the iPad.
    private func cell(of item: FileItem, @ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .takesDrops(on: item.isContainer ? item : folder, with: drops)
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
