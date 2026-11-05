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
        HStack(spacing: 2) {
            ForEach(Array(crumbs.enumerated()), id: \.offset) { index, crumb in
                let isLast = index == crumbs.count - 1
                crumbButton(crumb, isLast: isLast)
                // As in Explorer, the folder shown ends the path: its own
                // subfolders are in the list.
                if !isLast { separator(after: crumb) }
            }
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

    private func crumbButton(_ crumb: PathComponent, isLast: Bool) -> some View {
        Button {
            Task { await browser.navigate(pane: paneIndex, to: FileItem.ID(crumb.path)) }
        } label: {
            HStack(spacing: 4) {
                FolderIcon(id: FileItem.ID(crumb.path), size: Self.iconSize)
                Text(crumb.name)
                    .fontWeight(isLast ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .buttonStyle(.borderless)
        // The folder shown keeps its name longest; the ones above it shorten
        // first ("Long Folder Na…").
        .layoutPriority(isLast ? 1 : 0)
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

    /// This Mac, then the volume and the folders on it, as Explorer starts
    /// with This PC (ADR 0044); a boundary folder that is not a volume starts
    /// the path itself.
    private var crumbs: [PathComponent] {
        let thisMac = PathComponent(
            name: FileItem.computer().name, path: FileItem.ID.computer.rawValue)
        guard folder != .computer else { return [thisMac] }
        let path = pathCrumbs
        let volumes = Set(browser.locations.filter { $0.kind == .volume }.map(\.id.rawValue))
        guard let first = path.first, volumes.contains(first.path) else { return path }
        return [thisMac] + path
    }

    private var pathCrumbs: [PathComponent] {
        // A boundary folder starts the path like a volume: nothing above it is shown.
        let boundary = (LaunchOptions.boundary ?? []).map {
            MountPoint(path: $0.path, name: $0.lastPathComponent)
        }
        let mounts =
            browser.locations.filter { $0.kind == .volume }.map {
                MountPoint(path: $0.id.rawValue, name: $0.name)
            } + boundary
        return PathComponents.breadcrumbs(for: folder.rawValue, mountPoints: mounts)
    }
}
