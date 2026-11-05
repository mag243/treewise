import SwiftUI
import TreewiseCore
import TreewiseUI

/// The path of the folder shown, from the added folder it is in: one button
/// per folder, scrolled to the end.
struct PathBar: View {
    private static let padding: CGFloat = 8

    let browser: BrowserState
    let folder: FileItem.ID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(crumbs.enumerated()), id: \.offset) { index, crumb in
                        if index > 0 {
                            Image(systemName: "chevron.forward")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Button(crumb.name) {
                            Task { await browser.navigate(pane: 0, to: FileItem.ID(crumb.path)) }
                        }
                        .fontWeight(index == crumbs.count - 1 ? .semibold : .regular)
                        .id(index)
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

    /// Each added folder starts a path, as a volume does on the Mac.
    private var crumbs: [PathComponent] {
        let roots = browser.locations.map { MountPoint(path: $0.id.rawValue, name: $0.name) }
        return PathComponents.breadcrumbs(for: folder.rawValue, mountPoints: roots)
    }
}
