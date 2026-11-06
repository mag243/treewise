import SwiftUI
import TreewiseCore
import TreewiseUI
import UniformTypeIdentifiers

/// The address bar at the top of the window, as in Explorer (M5b): the path of
/// its folder, one button per folder, each a drop target, with a menu of the
/// subfolders behind each separator. A click on the empty part, or ⌘L, turns
/// it into a field to type a path in (`AddressField`).
struct AddressBar: View {
    private static let padding: CGFloat = 6
    private static let iconSize: CGFloat = 13
    private static let outlineRadius: CGFloat = 4

    @Environment(\.fileUndoManager) private var undoManager
    /// The path a drag is over, outlined.
    @State private var dropTarget: String?
    /// The subfolders behind each separator, by the path before it.
    @State private var subfolders: [String: [FileItem]] = [:]

    let browser: BrowserState
    let paneIndex: Int
    let folder: FileItem.ID
    @Binding var isEditing: Bool

    var body: some View {
        if isEditing {
            AddressField(browser: browser, paneIndex: paneIndex, folder: folder) {
                isEditing = false
            }
        } else {
            crumbsRow
        }
    }

    private var crumbsRow: some View {
        let crumbs = self.crumbs
        return HStack(spacing: 2) {
            // The first path that fits at full names: the folders at the start go behind
            // `«` one by one (ADR 0069). Without one that fits, the last, which shows only
            // the folder itself, is cut short in the middle.
            ViewThatFits(in: .horizontal) {
                ForEach(0..<crumbs.count, id: \.self) { hidden in
                    path(crumbs, hiding: hidden)
                }
            }
            .layoutPriority(1)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { isEditing = true }
                .accessibilityLabel(Text("Type a path"))
                .accessibilityAddTraits(.isButton)
        }
        .font(.system(size: 11))
        .padding(.horizontal, Self.padding)
        .task(id: folder) { await loadSubfolders() }
    }

    /// The path with its first `hidden` folders behind `«`.
    private func path(_ crumbs: [PathComponent], hiding hidden: Int) -> some View {
        HStack(spacing: 2) {
            if hidden > 0 {
                overflow(crumbs[..<hidden])
                separator(after: crumbs[hidden - 1])
            }
            ForEach(hidden..<crumbs.count, id: \.self) { index in
                let isLast = index == crumbs.count - 1
                crumbButton(crumbs[index], isLast: isLast)
                // As in Explorer, the folder shown ends the path: its own
                // subfolders are in the list.
                if !isLast { separator(after: crumbs[index]) }
            }
        }
    }

    /// `«`, with a menu of the folders it stands for, the nearest last.
    private func overflow(_ hidden: ArraySlice<PathComponent>) -> some View {
        Menu {
            ForEach(Array(hidden), id: \.path) { crumb in
                Button {
                    Task { await browser.navigate(pane: paneIndex, to: FileItem.ID(crumb.path)) }
                } label: {
                    Label {
                        Text(crumb.name)
                    } icon: {
                        Image(nsImage: FolderIcon.image(for: FileItem.ID(crumb.path)))
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.left.2").accessibilityLabel(Text("Folders Above"))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(Text("Folders Above"))
    }

    private func crumbButton(_ crumb: PathComponent, isLast: Bool) -> some View {
        // This Mac starts every path on a volume, so its icon says enough (ADR 0069).
        let iconOnly = !isLast && crumb.path == FileItem.ID.computer.rawValue
        return Button {
            Task { await browser.navigate(pane: paneIndex, to: FileItem.ID(crumb.path)) }
        } label: {
            HStack(spacing: 4) {
                FolderIcon(id: FileItem.ID(crumb.path), size: Self.iconSize)
                if !iconOnly {
                    Text(crumb.name)
                        .fontWeight(isLast ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .buttonStyle(.borderless)
        .help(iconOnly ? crumb.name : "")
        .accessibilityLabel(Text(crumb.name))
        .dropOutline(dropTarget == crumb.path, cornerRadius: Self.outlineRadius)
        .onDrop(
            of: DropRouting.contentTypes,
            delegate: FolderDropDelegate(
                folder: FileItem.ID(crumb.path), isTargeted: isDropTarget(crumb.path),
                drop: DropRouting.action(for: browser, undoManager: undoManager)))
    }

    /// The separator after a folder: a menu of the folders inside it.
    private func separator(after crumb: PathComponent) -> some View {
        AddressSeparator(
            folders: subfolders[crumb.path] ?? [],
            label: String(localized: "Folders in \(crumb.name)")
        ) { subfolder in
            Task { await browser.navigate(pane: paneIndex, to: subfolder) }
        }
        .fixedSize()
    }

    private func loadSubfolders() async {
        var loaded: [String: [FileItem]] = [:]
        for crumb in crumbs.dropLast() {
            loaded[crumb.path] = await browser.subfolders(of: FileItem.ID(crumb.path))
        }
        subfolders = loaded
    }

    private func isDropTarget(_ path: String) -> Binding<Bool> {
        Binding(
            get: { dropTarget == path },
            set: { isTargeted in
                if isTargeted {
                    dropTarget = path
                } else if dropTarget == path {
                    dropTarget = nil
                }
            })
    }

    /// The path from where it starts to the folder (ADR 0069).
    private var crumbs: [PathComponent] {
        let boundary = (LaunchOptions.boundary ?? []).map {
            MountPoint(path: $0.path, name: $0.lastPathComponent)
        }
        return browser.addressPath(of: folder, boundary: boundary)
    }
}
