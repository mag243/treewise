import AppKit
import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// A browser window: the sidebar, the command bar, one folder and the details
/// pane, with the
/// toolbar. A window is one of macOS's window tabs, and two folders side by
/// side are two windows (ADR 0037).
struct BrowserWindow: View {
    @Environment(\.openWindow) private var openWindow
    @FocusState private var isSearching: Bool
    /// Whether the address bar is a field to type a path in.
    @State private var isEditingAddress = false
    /// Whether the window shows a sheet, which leaves it alone for new tabs.
    @State private var showsSheet = false
    @State private var browser: BrowserState
    /// What the window was opened for as a tab; `nil` for a new window.
    private let request: TabRequest?
    /// The undo manager of all windows' file operations.
    private let undoManager: UndoManager
    @State private var host = WindowHost()

    /// Creates a window that follows `settings`. A tab starts at the folder it
    /// was opened for; a new window at the start folder when it can be shown,
    /// else at home (ADR 0023). All windows share `clipboard`, and register
    /// their file operations with `undoManager` (ADR 0037).
    init(
        settings: BrowserSettings, clipboard: SharedClipboard, undoManager: UndoManager,
        request: TabRequest?
    ) {
        self.undoManager = undoManager
        let home = FileItem.ID(LaunchOptions.homeFolder.path)
        let reader = LocalFileSystem(locations: LaunchOptions.locations)
        let lookUp = { (id: FileItem.ID) -> FileItem? in try? reader.currentItem(at: id) }
        let requested = request.map { FileItem.ID($0.folder) }.flatMap {
            lookUp($0)?.isContainer == true ? $0 : nil
        }
        self.request = request
        let browser = BrowserState(
            fileSystem: FileOperationRunner(locations: LaunchOptions.locations),
            watcher: DirectoryWatcher(watchesFileChanges: reader.isInCloudFolder),
            startFolder: requested ?? settings.startFolder(home: home, lookUp: lookUp),
            homeFolder: home, settings: settings, clipboard: clipboard)
        browser.licences = LaunchOptions.licenceKeeper(for: settings)
        _browser = State(initialValue: browser)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(browser: browser)
                .navigationSplitViewColumnWidth(
                    min: WindowWidths.sidebarMinimum, ideal: WindowWidths.sidebarIdeal,
                    max: WindowWidths.sidebarMaximum)
        } detail: {
            VStack(spacing: 0) {
                AddressRow(browser: browser, isEditing: $isEditingAddress)
                Divider()
                CommandBar(browser: browser, undoManager: undoManager) {
                    actions.windowBeside()
                }
                Divider()
                HStack(spacing: 0) {
                    PaneView(browser: browser, paneIndex: browser.layout.focusedPaneIndex)
                    if browser.settings.showsDetails {
                        Divider()
                        DetailsPane(browser: browser)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                OperationProgressView(browser: browser)
            }
        }
        // Keeps the command bar whole.
        .frame(minWidth: WindowWidths.windowMinimum)
        .environment(\.fileUndoManager, undoManager)
        .background(WindowReader { attach(to: $0) })
        .navigationTitle(title)
        .toolbar {
            BrowserToolbar(browser: browser, undoManager: undoManager)
        }
        // The address bar already names the folder; the title stays for the
        // tab bar, the Window menu and Mission Control.
        .toolbar(removing: .title)
        .searchable(text: query, placement: .toolbar, prompt: Text("Search \(title)"))
        .searchFocused($isSearching)
        .focusedSceneValue(\.browserActions, actions)
        .watchingSheets(of: host, showsSheet: $showsSheet)
        .alert(failureText, isPresented: showsFailure) {
            Button("OK") { browser.clearFailure() }
        }
        .onChange(of: browser.snapshot) { WindowSession.save() }
        .task { await start() }
    }

    /// Shows what the window was opened for: a restored tab, or for the first
    /// window of a launch the session before it, whose other tabs it opens.
    private func start() async {
        let groups = request == nil ? WindowSession.claim(from: browser.settings) : []
        let requested = request?.snapshot?.restored { _ in true }
        if let restored = groups.first?.tabs.first ?? requested {
            browser.restore(restored.layout, sort: restored.sort, viewMode: restored.viewMode)
        }
        await browser.start()
        guard !groups.isEmpty else { return }
        await WindowSession.restore(groups, after: host.awaitWindow())
    }

    /// Gives `window` a fixed size, centered on the main display, for
    /// screenshots (ADR 0041).
    private func show(_ window: NSWindow, at size: CGSize) {
        window.setContentSize(size)
        guard let screen = NSScreen.screens.first?.visibleFrame else { return }
        window.setFrameOrigin(
            CGPoint(
                x: screen.midX - window.frame.width / 2, y: screen.midY - window.frame.height / 2))
    }

    private func attach(to window: NSWindow) {
        WindowTabs.shared.openWindow = openWindow
        WindowTabs.shared.attach(window, for: request, browser: browser)
        WindowSession.watch(browser.settings)
        WindowSession.open(window)
        if let size = LaunchOptions.windowSize { show(window, at: size) }
        host.set(window)
    }

    private var focusedTab: TabModel.ID {
        browser.layout.focusedPane.activeTabID
    }

    private var title: String {
        browser.content(of: focusedTab).folder?.name ?? "Treewise"
    }

    private var query: Binding<String> {
        Binding(
            get: { browser.content(of: focusedTab).query },
            set: { browser.setQuery($0, in: focusedTab) })
    }

    private var actions: BrowserActions {
        BrowserActions(
            browser: browser, undoManager: undoManager, showsSheet: showsSheet,
            focusSearch: { isSearching = true }, editAddress: { isEditingAddress = true })
    }

    private var failureText: String {
        browser.failure.map { FailureMessage.text(for: $0, locale: .autoupdatingCurrent) } ?? ""
    }

    private var showsFailure: Binding<Bool> {
        Binding(get: { browser.failure != nil }, set: { if !$0 { browser.clearFailure() } })
    }
}
