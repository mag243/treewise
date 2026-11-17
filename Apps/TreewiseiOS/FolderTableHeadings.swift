import SwiftUI
import TreewiseCore
import TreewiseUI

/// The table's headings (ADR 0125): tapping one sorts by its column, tapping it again turns
/// the order round, as on the Mac; the line after a heading resizes a column; the "…" at the
/// end chooses the columns, as in Files.
struct FolderTableHeadings: View {
    /// The room above and below the headings.
    private static let padding: CGFloat = 10

    let browser: BrowserState
    let settings: BrowserSettings
    /// The room the name has beyond its minimum, which a column may take as it widens.
    let spareWidth: CGFloat

    private var layout: TableColumnLayout { settings.tableColumns }

    var body: some View {
        let columns = FolderTableColumn.shown(in: layout)
        HStack(spacing: FolderTableColumn.spacing) {
            ForEach(Array(columns.enumerated()), id: \.element) { index, column in
                heading(column)
                    .inColumn(column, of: layout)
                    .overlay(alignment: .trailing) {
                        if index + 1 < columns.count,
                            case .detail(let resized) = columns[index + 1]
                        {
                            ColumnResizeLine(
                                settings: settings, resized: resized, follows: column,
                                spareWidth: spareWidth)
                        }
                    }
            }
            columnMenu
        }
        .font(.subheadline)
        .padding(.horizontal, FolderTableColumn.margin)
        .padding(.vertical, Self.padding)
    }

    private func heading(_ column: FolderTableColumn) -> some View {
        Button {
            browser.sort(by: column.sortColumn)
        } label: {
            HStack(spacing: 4) {
                Text(column.title).fontWeight(.semibold)
                if browser.sort.column == column.sortColumn {
                    Image(systemName: browser.sort.ascending ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .lineLimit(1)
        }
        .accessibilityLabel(Text(column.title))
    }

    private var columnMenu: some View {
        Menu {
            ForEach(FolderColumn.allCases, id: \.self) { column in
                Toggle(
                    FolderTableColumn.title(of: column),
                    isOn: Binding(
                        get: { layout.isShown(column) },
                        set: { _ in settings.tableColumns.toggle(column) }))
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: FolderTableColumn.menuWidth)
        }
        .accessibilityLabel(Text("Columns"))
        // The UI tests find it by it.
        .accessibilityIdentifier("columns")
    }
}

/// The line between two headings: dragging it resizes the column to its right, the name
/// taking or giving the room, so that the line stays under the finger; a double tap gives
/// the column its default width back (ADR 0125). Its target is wider than the line, for a
/// finger.
struct ColumnResizeLine: View {
    /// The width of the line's target.
    private static let targetWidth: CGFloat = 20
    /// The height of the line drawn.
    private static let lineHeight: CGFloat = 16

    let settings: BrowserSettings
    /// The column the line resizes: the one after it.
    let resized: FolderColumn
    /// The column the line follows.
    let follows: FolderTableColumn
    /// The room the name has beyond its minimum, the most the column may widen by.
    let spareWidth: CGFloat
    /// The column's width and the name's spare room as the drag began.
    @State private var start: (width: Double, spare: Double)?

    var body: some View {
        Rectangle()
            .fill(.separator)
            .frame(width: 1, height: Self.lineHeight)
            .frame(width: Self.targetWidth)
            .contentShape(Rectangle())
            // In the middle of the room between this column and the next.
            .padding(.trailing, -(Self.targetWidth + FolderTableColumn.spacing) / 2)
            .gesture(drag)
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { settings.tableColumns.resetWidth(of: resized) }
            )
            .accessibilityLabel(Text("Width of \(FolderTableColumn.title(of: resized))"))
            .accessibilityIdentifier("resize-after-\(follows.identifier)")
    }

    private var drag: some Gesture {
        // Measured on the screen: the line moves with the finger, so in its own space the
        // drag would seem to go half as far.
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                let begun =
                    start ?? (settings.tableColumns.width(of: resized), Double(spareWidth))
                start = begun
                // Dragging to the left widens the column, as far as the name can give.
                let widened = min(-Double(value.translation.width), begun.spare)
                settings.tableColumns.setWidth(begun.width + widened, of: resized)
            }
            .onEnded { _ in start = nil }
    }
}
