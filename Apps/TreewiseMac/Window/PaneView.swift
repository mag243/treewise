import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// The window's folder: its list or icons and the status bar with the view
/// buttons.
struct PaneView: View {
    private static let barPadding: CGFloat = 4
    private static let statusPadding: CGFloat = 10

    @Environment(\.fileUndoManager) private var undoManager

    let browser: BrowserState
    let paneIndex: Int
    /// The downloads running among the files shown (ADR 0051).
    @State private var downloads: [FileItem.ID: Double] = [:]

    var body: some View {
        // Observation can redraw a removed pane once more before ForEach drops it.
        if let pane = browser.layout.pane(at: paneIndex) { paneBody(pane) }
    }

    @ViewBuilder
    private func paneBody(_ pane: PaneModel) -> some View {
        let tab = pane.activeTabID
        let content = browser.content(of: tab)
        let items = browser.visibleItems(of: tab)
        let isActive = browser.layout.focusedPaneIndex == paneIndex
        let onlyOnline = items.filter(\.isOnlyOnline).map(\.id)
        VStack(spacing: 0) {
            folderView(content: content, items: items, isActive: isActive, tab: tab)
                .task(id: onlyOnline) { await followDownloads(of: onlyOnline) }
                .overlay {
                    if content.failure != nil {
                        failureMessage(content.failure)
                    } else if items.isEmpty && content.folder != nil {
                        Text(
                            ListPlaceholder.text(query: content.query, locale: .autoupdatingCurrent)
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            Divider()
            statusBar(items: items, content: content)
        }
    }

    /// Keeps `downloads` up to date. A download that ends changes the file, so
    /// the folder is read again, which also ends this following for that file.
    private func followDownloads(of files: [FileItem.ID]) async {
        for await report in DownloadMonitor().downloads(of: files) {
            let ended = report.count < downloads.count
            downloads = report
            if ended { await browser.refresh(pane: paneIndex) }
        }
        downloads = [:]
    }

    /// The status bar as in Explorer: the counts at the left, the view
    /// buttons at the right (M5b).
    private func statusBar(items: [FileItem], content: TreewiseUI.TabContent) -> some View {
        HStack {
            Text(statusText(items: items, content: content))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("View", selection: viewMode) {
                Label("as List", systemImage: "list.bullet").tag(ViewMode.list)
                Label("as Icons", systemImage: "square.grid.2x2").tag(ViewMode.icons)
            }
            .pickerStyle(.segmented)
            .labelStyle(.iconOnly)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
            .help(Text("Show items as icons or as a list"))
        }
        .font(.system(size: 11))
        .padding(.horizontal, Self.statusPadding)
        .padding(.vertical, Self.barPadding)
    }

    private var viewMode: Binding<ViewMode> {
        Binding(get: { browser.viewMode }, set: { browser.viewMode = $0 })
    }

    /// The list or the icon view, as the window shows folders (ADR 0025).
    @ViewBuilder
    private func folderView(
        content: TreewiseUI.TabContent, items: [FileItem], isActive: Bool, tab: TabModel.ID
    ) -> some View {
        let renameRequest = isActive ? browser.renameRequest : nil
        switch browser.viewMode {
        case .list:
            FileTableView(
                folder: content.folder, items: items, selection: content.selection,
                sort: browser.sort, isActive: isActive, cutItems: cutItems,
                renameRequest: renameRequest, downloads: downloads,
                showsExtensions: browser.settings.showsExtensions,
                rowHeight: browser.settings.rowDensity.rowHeight, actions: actions(for: tab))
        case .icons:
            FileGridView(
                folder: content.folder, items: items, selection: content.selection,
                isActive: isActive, cutItems: cutItems, renameRequest: renameRequest,
                downloads: downloads, showsExtensions: browser.settings.showsExtensions,
                actions: actions(for: tab))
        }
    }

    /// The items cut to the clipboard, which the list dims.
    private var cutItems: Set<FileItem.ID> {
        guard let clipboard = browser.clipboard, clipboard.mode == .cut else { return [] }
        return Set(clipboard.items.map(\.id))
    }

    private func statusText(items: [FileItem], content: TreewiseUI.TabContent) -> String {
        let selected = items.filter { content.selection.contains($0.id) }
        return StatusLine.text(
            itemCount: items.count, selectedCount: content.selection.count,
            selectedSize: selected.compactMap(\.size).reduce(0, +),
            availableCapacity: content.availableCapacity, locale: .autoupdatingCurrent)
    }

    private func actions(for tab: TabModel.ID) -> FileTableActions {
        FileTableActions(
            select: { browser.setSelection($0, in: tab) },
            open: { item, command, option in
                open(
                    item,
                    in: OpenPlacement.forOpening(
                        command: command, option: option,
                        preferred: browser.settings.doubleClickOpensIn))
            },
            sort: { browser.sort(by: $0) },
            focus: { browser.focusPane(paneIndex) },
            cut: clipboard.cut, copy: clipboard.copy, paste: clipboard.paste,
            canPaste: { clipboard.canPaste },
            rename: { item, name in
                Task { await browser.rename(item, to: name, undoManager: undoManager) }
            },
            renameStarted: {
                browser.renameRequest = nil
                defer { browser.renameSuggests = false }
                return browser.renameSuggests
            },
            suggestName: { item, field in
                NameSuggestionMenu.show(
                    for: item, in: field, browser: browser, undoManager: undoManager)
            },
            contextMenu: { contextMenu.menu(for: $0) },
            drop: DropRouting.action(for: browser, undoManager: undoManager))
    }

    private var contextMenu: FileContextMenu {
        FileContextMenu(
            browser: browser, paneIndex: paneIndex, undoManager: undoManager,
            cut: clipboard.cut, copy: clipboard.copy, paste: clipboard.paste,
            canPaste: { clipboard.canPaste })
    }

    private var clipboard: ClipboardCommands {
        ClipboardCommands(browser: browser, undoManager: undoManager)
    }

    private func open(_ item: FileItem, in placement: OpenPlacement) {
        Task { await ItemOpening.open([item], from: paneIndex, in: placement, browser: browser) }
    }

    @ViewBuilder
    private func failureMessage(_ failure: FileSystemError?) -> some View {
        if let failure {
            Text(FailureMessage.text(for: failure, locale: .autoupdatingCurrent))
        }
    }
}
