import SwiftUI
import TreewiseCore
import TreewiseUI

/// A row of a narrow folder (ADR 0116): the item's name with its icon, and the date and size
/// beneath it; a folder's row ends in a chevron, as it opens.
struct FolderNarrowRow: View {
    /// The room the icon takes, so the names line up.
    private static let iconWidth: CGFloat = 28

    let item: FileItem
    let showsExtensions: Bool

    private let formats = ItemFormats()

    var body: some View {
        HStack {
            Image(systemName: ItemSymbol.name(for: item))
                .foregroundStyle(item.isContainer ? Color.accentColor : .secondary)
                .frame(width: Self.iconWidth)
            VStack(alignment: .leading) {
                Text(DisplayName.text(for: item, showsExtension: showsExtensions))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            OnlyOnlineMark(item: item)
            if item.isContainer {
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var subtitle: String {
        item.isContainer
            ? formats.date(of: item)
            : formats.date(of: item) + " – " + formats.size(of: item)
    }
}
