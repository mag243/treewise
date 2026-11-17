import SwiftUI
import TreewiseCore
import TreewiseUI
import UniformTypeIdentifiers

/// The path of the folder shown, from the added folder it is in: one button
/// per folder, scrolled to the end.
struct PathBar: View {
    private static let padding: CGFloat = 8

    let browser: BrowserState
    let folder: FileItem.ID
    let drops: ItemDrops

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(crumbs.enumerated()), id: \.offset) { index, crumb in
                        if index > 0 {
                            SubfolderMenu(
                                browser: browser, folder: FileItem.ID(crumbs[index - 1].path),
                                next: FileItem.ID(crumb.path), name: crumbs[index - 1].name)
                        }
                        Button(crumb.name) {
                            Task { await browser.navigate(pane: 0, to: FileItem.ID(crumb.path)) }
                        }
                        .fontWeight(index == crumbs.count - 1 ? .semibold : .regular)
                        .id(index)
                        .takesDrops(
                            on: drops.locations.item(at: FileItem.ID(crumb.path)), with: drops)
                    }
                }
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.vertical, Self.padding)
            }
            .onChange(of: folder, initial: true) {
                proxy.scrollTo(crumbs.count - 1, anchor: .trailing)
            }
        }
    }

    private var crumbs: [PathComponent] { Self.crumbs(of: folder, in: browser) }

    /// The path of `folder`: each added folder starts one, as a volume does on the Mac.
    static func crumbs(of folder: FileItem.ID, in browser: BrowserState) -> [PathComponent] {
        let roots = browser.locations.map { MountPoint(path: $0.id.rawValue, name: $0.name) }
        return PathComponents.breadcrumbs(for: folder.rawValue, mountPoints: roots)
    }

    /// The name the path bar gives `folder`, before the folder itself is read.
    static func name(of folder: FileItem.ID, in browser: BrowserState) -> String {
        crumbs(of: folder, in: browser).last?.name ?? ""
    }
}
