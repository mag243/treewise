import QuickLookThumbnailing
import SwiftUI
import TreewiseCore
import TreewiseUI
import UIKit

/// An item's icon in a row: for a file the look the user chose in Settings (ADR 0151),
/// one of Treewise's own pages or the system's icon; for a folder, a location or a
/// package its symbol.
struct FileIcon: View {
    let item: FileItem
    /// The icon's side, following the text size as a symbol in a label does.
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = FilePageStyle.side
    @Environment(\.fileIconLook) private var look

    var body: some View {
        if item.kind != .file {
            symbol
        } else if look == .system {
            SystemFileIcon(item: item, side: side) { symbol }
        } else {
            FilePage(badge: FileBadge(fileName: item.name), look: look, side: side)
        }
    }

    private var symbol: some View {
        Image(systemName: ItemSymbol.name(for: item))
            .foregroundStyle(item.isContainer ? Color.accentColor : .secondary)
    }
}

extension EnvironmentValues {
    /// How files' icons look, from Settings.
    @Entry var fileIconLook: FileIconLook = .pageWithLabel
}

/// The system's icon for a file's type, as Files shows it, made by Quick Look once per
/// type; until then, and where Quick Look gives none, the item's symbol.
private struct SystemFileIcon<Fallback: View>: View {
    let item: FileItem
    let side: CGFloat
    @ViewBuilder let fallback: () -> Fallback
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
                fallback()
            }
        }
        .task(id: "\(colorScheme) \(item.id.rawValue)") {
            icon = nil
            icon = await cache.icon(for: item, size: Int(side))
        }
    }

    private var cache: TypeIconCache<UIImage> { SystemFileIcons.cache(for: colorScheme) }
}

/// The icons Quick Look made for the files' types, shared by every row.
@MainActor
private enum SystemFileIcons {
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

/// Treewise's own icon of a file: a page with a folded corner in one of three looks.
private struct FilePage: View {
    let badge: FileBadge
    let look: FileIconLook
    let side: CGFloat

    var body: some View {
        Group {
            switch look {
            case .filledPage: filled
            case .pageWithLabel: labelled
            default: banded
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    private var colour: Color { FilePageStyle.colour(of: badge.kind) }
    private var line: CGFloat { max(1, side * FilePageStyle.lineRatio) }
    private var page: FoldedPage { FoldedPage(fold: side * FilePageStyle.foldRatio) }
    private var width: CGFloat { side * FilePageStyle.widthRatio }

    /// A light page with a band in the colour holding the extension.
    private var banded: some View {
        ZStack(alignment: .bottom) {
            page.fill(colour.opacity(FilePageStyle.tintOpacity))
            page.stroke(colour, lineWidth: line)
            label(size: FilePageStyle.labelRatio)
                .frame(width: width, height: side * FilePageStyle.bandRatio)
                .background(
                    colour, in: .rect(bottomLeadingRadius: line, bottomTrailingRadius: line))
        }
        .frame(width: width, height: side)
    }

    /// A page in the colour with the extension on it.
    private var filled: some View {
        ZStack(alignment: .bottom) {
            page.fill(colour)
            page.stroke(colour, lineWidth: line)
            FoldFlap(fold: side * FilePageStyle.foldRatio)
                .fill(.white.opacity(FilePageStyle.flapOpacity))
            label(size: FilePageStyle.filledLabelRatio)
                .frame(width: width, height: side * FilePageStyle.bandRatio)
                .padding(.bottom, line)
        }
        .frame(width: width, height: side)
    }

    /// A neutral page with a label in the colour sticking out at its left.
    private var labelled: some View {
        ZStack(alignment: .bottomLeading) {
            page.fill(Color(.systemBackground))
                .overlay(page.stroke(Color(.secondaryLabel), lineWidth: line))
                .frame(width: width, height: side)
                .frame(maxWidth: .infinity, alignment: .center)
            Group {
                if badge.label != nil {
                    label(size: FilePageStyle.tagLabelRatio)
                        .padding(.horizontal, side * FilePageStyle.tagPaddingRatio)
                        .frame(width: tagWidth, height: side * FilePageStyle.tagRatio)
                        .background(colour, in: .rect(cornerRadius: side * FilePageStyle.tagCorner))
                } else {
                    colour.frame(width: width / 2, height: side * FilePageStyle.barRatio)
                        .clipShape(.capsule)
                        .padding(.leading, side * FilePageStyle.barInsetRatio)
                }
            }
            .padding(.bottom, side * FilePageStyle.tagBottomRatio)
        }
    }

    /// The label's width on a neutral page: room for its letters, at most the icon's side.
    private var tagWidth: CGFloat {
        let letters = CGFloat(badge.label?.count ?? 0)
        return min(
            side, side * (FilePageStyle.tagLetterRatio * letters + FilePageStyle.tagEndsRatio))
    }

    /// The extension in white, drawn rather than laid out as text: it is part of the
    /// picture, which the row's name already says, so it is no element of its own.
    private func label(size ratio: CGFloat) -> some View {
        let text = badge.label ?? ""
        let fontSize = side * ratio
        return Canvas { context, size in
            let resolved = context.resolve(
                Text(verbatim: text)
                    .font(.system(size: fontSize, weight: .heavy).width(.condensed))
                    .foregroundStyle(.white))
            let needs = resolved.measure(in: CGSize(width: CGFloat.infinity, height: size.height))
            let scale = max(FilePageStyle.labelShrink, min(1, size.width / max(needs.width, 1)))
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
            context.draw(resolved, at: .zero)
        }
        .padding(.horizontal, line)
    }
}

/// A page's outline with its top right corner folded over.
private struct FoldedPage: Shape {
    let fold: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY + fold))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        return path
    }
}

/// The folded corner of a page, as a triangle.
private struct FoldFlap: Shape {
    let fold: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY + fold))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        path.closeSubpath()
        return path
    }
}
