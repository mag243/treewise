import QuickLookThumbnailing
import SwiftUI
import TreewiseCore
import TreewiseUI
import UIKit

/// An item's icon in a row (ADR 0148): for a file the system's icon for its type, as Files
/// shows it, made by Quick Look once per type; until then, for a folder and where Quick
/// Look gives none, its symbol.
struct FileIcon: View {
    let item: FileItem
    /// The icon's side, following the text size as a symbol in a label does.
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = FileIcons.side
    /// Light or dark, whose icons Quick Look makes apart.
    @Environment(\.colorScheme) private var colorScheme
    @State private var icon: UIImage?

    var body: some View {
        Group {
            if let icon = icon ?? cache.cachedIcon(for: item, size: Int(side)) {
                Image(uiImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: side, height: side)
            } else {
                Image(systemName: ItemSymbol.name(for: item))
                    .foregroundStyle(item.isContainer ? Color.accentColor : .secondary)
            }
        }
        .task(id: "\(colorScheme) \(item.id.rawValue)") {
            icon = nil
            guard item.kind == .file else { return }
            icon = await cache.icon(for: item, size: Int(side))
        }
    }

    private var cache: TypeIconCache<UIImage> { FileIcons.cache(for: colorScheme) }
}

/// The icons Quick Look made for the files' types, shared by every row.
@MainActor
enum FileIcons {
    /// A row's icon side at the default text size, in points.
    static let side: CGFloat = 22
    /// The scale the icons are made at, the highest a screen has, so one serves every screen.
    private nonisolated static let scale: CGFloat = 3

    private static let light = TypeIconCache<UIImage> { item, size in await make(item, size) }
    private static let dark = TypeIconCache<UIImage> { item, size in await make(item, size) }

    /// The icons of an appearance, made while the app shows it.
    static func cache(for colorScheme: ColorScheme) -> TypeIconCache<UIImage> {
        colorScheme == .dark ? dark : light
    }

    /// Quick Look's icon for the item's type, without reading the file, so a file that is
    /// only online is not downloaded.
    private nonisolated static func make(_ item: FileItem, _ size: Int) async -> UIImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: URL(fileURLWithPath: item.id.rawValue),
            size: CGSize(width: size, height: size), scale: scale, representationTypes: .icon)
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            .uiImage
    }
}
