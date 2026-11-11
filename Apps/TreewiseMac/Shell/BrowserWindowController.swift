import AppKit
import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// A browser window (ADR 0081): the sidebar and the folder side by side in a
/// split view, with the toolbar. A window is one of macOS's window tabs, and
/// two folders side by side are two windows (ADR 0037). Its menu items and
/// toolbar items reach it through the responder chain.
@MainActor
final class BrowserWindowController: NSWindowController, NSWindowDelegate {
    /// The size of a new window, which the runner's 1024-point screen holds.
    private static let defaultSize = NSSize(width: 960, height: 600)
    private static let minimumHeight: CGFloat = 400

    /// The folders the window shows.
    let browser: BrowserState
    /// What the window's own views share with it.
    let model = WindowModel()
    private let request: TabRequest?
    private let toolbarItems: BrowserToolbar
    private var lastSnapshot: WindowSnapshot?
    private var isShowingFailure = false

    /// Creates a window that follows `settings`. A tab starts at the folder it
    /// was opened for; a new window at the start folder when it can be shown,
    /// else at home (ADR 0023).
    init(request: TabRequest?) {
        self.request = request
        browser = Self.makeBrowser(for: request)
        toolbarItems = BrowserToolbar(browser: browser)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        super.init(window: window)
        window.delegate = self
        // Treewise restores its windows itself, on every Mac (ADR 0038).
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.tabbingIdentifier = "browser"
        // The address bar already names the folder; the title stays for the
        // tab bar, the Window menu and Mission Control.
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.contentViewController = makeSplit()
        window.toolbar = toolbarItems.toolbar
        // The window is no narrower than the command bar with its icons (ADR 0037).
        window.contentMinSize = NSSize(
            width: WindowWidths.windowMinimum, height: Self.minimumHeight)
        window.setContentSize(LaunchOptions.windowSize ?? Self.defaultSize)
        Observing.follow(self) { $0.update() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private static func makeBrowser(for request: TabRequest?) -> BrowserState {
        let settings = AppServices.settings
        let home = FileItem.ID(LaunchOptions.homeFolder.path)
        let reader = LocalFileSystem(locations: LaunchOptions.locations)
        let lookUp = { (id: FileItem.ID) -> FileItem? in try? reader.currentItem(at: id) }
        let requested = request.map { FileItem.ID($0.folder) }.flatMap {
            lookUp($0)?.isContainer == true ? $0 : nil
        }
        let browser = BrowserState(
            fileSystem: FileOperationRunner(locations: LaunchOptions.locations),
            watcher: DirectoryWatcher(watchesFileChanges: reader.isInCloudFolder),
            startFolder: requested ?? settings.startFolder(home: home, lookUp: lookUp),
            homeFolder: home, settings: settings, clipboard: AppServices.clipboard)
        browser.licences = LaunchOptions.licenceKeeper(for: settings)
        return browser
    }

    private func makeSplit() -> NSSplitViewController {
        let split = NSSplitViewController()
        let sidebar = NSSplitViewItem(
            sidebarWithViewController: Self.hosting(SidebarView(browser: browser)))
        sidebar.minimumThickness = WindowWidths.sidebarMinimum
        sidebar.maximumThickness = WindowWidths.sidebarMaximum
        split.addSplitViewItem(sidebar)
        let content = BrowserContentController(browser: browser, model: model) { [weak self] in
            self?.actions.windowBeside()
        }
        split.addSplitViewItem(NSSplitViewItem(viewController: content))
        return split
    }

    private static func hosting(_ view: some View) -> NSViewController {
        let controller = NSHostingController(
            rootView: view.environment(\.fileUndoManager, SharedUndo.manager))
        // The window sets the size; the views fill what they are given.
        controller.sizingOptions = []
        return controller
    }

    /// Shows the window, centered for screenshots (ADR 0041), and then what
    /// it was opened for: a restored tab, or for the first window of a
    /// launch the session before it, whose other tabs it opens.
    func open(restoringSession: Bool) {
        guard let window else { return }
        if LaunchOptions.windowSize != nil { Self.center(window) }
        WindowSession.watch(browser.settings)
        WindowSession.open(window)
        window.makeKeyAndOrderFront(nil)
        if let splitView = (window.contentViewController as? NSSplitViewController)?.splitView {
            splitView.setPosition(WindowWidths.sidebarIdeal, ofDividerAt: 0)
        }
        let groups = restoringSession ? WindowSession.claim(from: browser.settings) : []
        let requested = request?.snapshot?.restored { _ in true }
        if let restored = groups.first?.tabs.first ?? requested {
            browser.restore(restored.layout, sort: restored.sort, viewMode: restored.viewMode)
        }
        Task {
            await browser.start()
            if !groups.isEmpty { WindowSession.restore(groups, after: window) }
        }
    }

    /// Puts `window` in the middle of the main display.
    private static func center(_ window: NSWindow) {
        guard let screen = NSScreen.screens.first?.visibleFrame else { return }
        window.setFrameOrigin(
            CGPoint(
                x: screen.midX - window.frame.width / 2, y: screen.midY - window.frame.height / 2))
    }

    /// What the menu bar and the toolbar ask of this window.
    var actions: BrowserActions {
        BrowserActions(
            browser: browser, undoManager: SharedUndo.manager,
            showsSheet: window?.attachedSheet != nil,
            focusSearch: { [weak self] in self?.focusSearch() },
            editAddress: { [weak self] in self?.model.isEditingAddress = true })
    }

    private func focusSearch() {
        window?.makeFirstResponder(toolbarItems.searchField)
    }

    // MARK: - Following the browser

    /// Follows what the window shows in its title, search field and session,
    /// and shows a failure.
    private func update() {
        let tab = browser.layout.focusedPane.activeTabID
        let title = browser.content(of: tab).folder?.name ?? "Treewise"
        window?.title = title
        toolbarItems.show(title: title, query: browser.content(of: tab).query)
        let snapshot = browser.snapshot
        if let lastSnapshot, lastSnapshot != snapshot { WindowSession.save() }
        lastSnapshot = snapshot
        if let failure = browser.failure { show(failure) }
    }

    /// Shows a failure as a sheet of the window, as every Mac app does.
    private func show(_ failure: FileSystemError) {
        guard !isShowingFailure, let window else { return }
        isShowingFailure = true
        let alert = NSAlert()
        alert.messageText = FailureMessage.text(for: failure, locale: .autoupdatingCurrent)
        alert.beginSheetModal(for: window) { [weak self] _ in
            self?.isShowingFailure = false
            self?.browser.clearFailure()
        }
    }

    // MARK: - NSWindowDelegate

    /// Every window's file operations share one history (ADR 0037).
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        SharedUndo.manager
    }

    func windowWillClose(_ notification: Notification) {
        WindowTabs.shared.closed(self)
    }
}

/// What a browser window's own views share with the window.
@MainActor
@Observable
final class WindowModel {
    /// Whether the address bar is a field to type a path in.
    var isEditingAddress = false
}
