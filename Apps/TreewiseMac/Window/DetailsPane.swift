import SwiftUI
import TreewiseCore
import TreewiseUI

/// Explorer's details pane at the right of the window (M5b): a preview of the
/// selected item and its name, kind, size, date and folder, or the count and
/// total size of several (`ItemDetails`).
struct DetailsPane: View {
    static let width: CGFloat = 260
    private static let previewHeight: CGFloat = 200
    private static let iconSize: CGFloat = 96
    private static let padding: CGFloat = 12

    let browser: BrowserState

    var body: some View {
        let details = ItemDetails(
            browser.selectedItems, calendar: .autoupdatingCurrent, locale: .autoupdatingCurrent,
            timeZone: .autoupdatingCurrent, now: .now)
        VStack(alignment: .leading, spacing: Self.padding) {
            preview(details.previewItem)
                .frame(maxWidth: .infinity)
                .frame(height: Self.previewHeight)
            Text(details.title)
                .font(.headline)
                .lineLimit(2)
                .textSelection(.enabled)
            Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 4) {
                ForEach(details.rows, id: \.label) { row in
                    GridRow {
                        Text(row.label).foregroundStyle(.secondary)
                        Text(row.value).textSelection(.enabled)
                    }
                }
            }
            .font(.callout)
            Spacer()
        }
        .padding(Self.padding)
        .frame(width: Self.width)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Details"))
    }

    @ViewBuilder
    private func preview(_ item: FileItem.ID?) -> some View {
        // A file kept only online shows its icon: a preview could download it (ADR 0051).
        if let selected = browser.selectedItems.first, selected.id.isInsideArchive {
            // Selecting an entry extracts nothing: its preview waits for Quick Look.
            Image(nsImage: ItemIcon.image(for: selected))
                .resizable()
                .scaledToFit()
                .frame(width: Self.iconSize, height: Self.iconSize)
        } else if let item, let selected = browser.selectedItems.first, !selected.isContainer,
            !selected.isOnlyOnline
        {
            QuickLookPreview(item: item)
        } else {
            let folder = item ?? browser.layout.focusedPane.activeTab.folder
            FolderIcon(id: folder, size: Self.iconSize)
        }
    }
}
