import SwiftUI
import TreewiseCore
import TreewiseUI

/// The folder as a list, on a narrow screen: each row the name, with the
/// date and size beneath it.
struct FolderList: View {
    let browser: BrowserState
    let items: [FileItem]
    let settings: BrowserSettings
    let actions: ItemActions

    private let formats = ItemFormats()

    var body: some View {
        List(items, selection: selection) { item in
            HStack {
                Image(systemName: ItemSymbol.name(for: item))
                    .foregroundStyle(item.isContainer ? Color.accentColor : .secondary)
                    .frame(width: 28)
                VStack(alignment: .leading) {
                    Text(DisplayName.text(for: item, showsExtension: settings.showsExtensions))
                        .lineLimit(1)
                    Text(subtitle(of: item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if item.isContainer {
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .listStyle(.plain)
        .contextMenu(forSelectionType: FileItem.ID.self) { ids in
            ItemMenu(items: items.filter { ids.contains($0.id) }, actions: actions)
        } primaryAction: { ids in
            if let item = items.first(where: { ids.contains($0.id) }) { actions.open(item) }
        }
    }

    private func subtitle(of item: FileItem) -> String {
        item.isContainer
            ? formats.date(of: item)
            : formats.date(of: item) + " – " + formats.size(of: item)
    }

    private var selection: Binding<Set<FileItem.ID>> {
        let tab = browser.layout.focusedPane.activeTabID
        return Binding(
            get: { browser.content(of: tab).selection },
            set: { browser.setSelection($0, in: tab) })
    }
}

/// The texts of an item's date, size and kind, as the Mac's list shows them.
struct ItemFormats {
    private let dates = ItemDateFormatter(
        calendar: .autoupdatingCurrent, locale: .autoupdatingCurrent, timeZone: .autoupdatingCurrent
    )
    private let sizes = ItemSizeFormatter(locale: .autoupdatingCurrent)
    private let kinds = KindFormatter(locale: .autoupdatingCurrent)

    func date(of item: FileItem) -> String {
        dates.string(for: item.modified, relativeTo: .now)
    }

    func size(of item: FileItem) -> String {
        sizes.string(for: item)
    }

    func kind(of item: FileItem) -> String {
        kinds.string(for: item)
    }
}
