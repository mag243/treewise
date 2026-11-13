import AppKit
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
    /// The sidebar's width as chosen, kept with the window (ADR 0093); a sidebar that gives
    /// way to a narrower window keeps it for when there is room again.
    private var chosenSidebarWidth: CGFloat?
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
        // AppKit restores the window at the next launch (ADR 0083).
        window.isRestorable = true
        window.identifier = BrowserWindowRestoration.identifier
        window.restorationClass = BrowserWindowRestoration.self
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
            sidebarWithViewController: SidebarController(browser: browser))
        sidebar.minimumThickness = WindowWidths.sidebarMinimum
        sidebar.maximumThickness = WindowWidths.sidebarMaximum
        split.addSplitViewItem(sidebar)
        let content = BrowserContentController(browser: browser, model: model) { [weak self] in
            self?.actions.windowBeside()
        }
        let folderSide = NSSplitViewItem(viewController: content)
        // The folder side keeps the command bar's width, so the sidebar gives way first.
        folderSide.minimumThickness = WindowWidths.folderMinimum
        split.addSplitViewItem(folderSide)
        NotificationCenter.default.addObserver(
            self, selector: #selector(sidebarResized(_:)),
            name: NSSplitView.didResizeSubviewsNotification, object: split.splitView)
        return split
    }

    /// Shows the window, centered for screenshots (ADR 0041), at the folder
    /// it was opened for.
    func open() {
        guard let window else { return }
        if LaunchOptions.windowSize != nil { Self.center(window) }
        window.makeKeyAndOrderFront(nil)
        showSidebarAtItsWidth()
        start()
    }

    /// Starts the window at the folder it showed before a restart, for AppKit
    /// to show it where it was (ADR 0083), with its sidebar as wide as it was.
    func openRestored() {
        showSidebarAtItsWidth()
        // AppKit sets the window's frame after this; the width is set again once it has.
        DispatchQueue.main.async { [weak self] in self?.showSidebarAtItsWidth() }
        start()
    }

    private var splitView: NSSplitView? {
        (window?.contentViewController as? NSSplitViewController)?.splitView
    }

    /// Sets the sidebar to the window's own width, else the last one chosen, else the
    /// ideal (ADR 0093).
    private func showSidebarAtItsWidth() {
        let width = CGFloat(
            SidebarWidth.start(
                restored: request?.snapshot?.sidebarWidth,
                lastChosen: AppServices.settings.sidebarWidth))
        chosenSidebarWidth = width
        splitView?.setPosition(width, ofDividerAt: 0)
    }

    /// Keeps the width the user dragged the sidebar to, for this window and a new one.
    /// Only a drag of the divider tells its index; a window made narrower does not.
    @objc private func sidebarResized(_ notification: Notification) {
        guard notification.userInfo?["NSSplitViewDividerIndex"] != nil,
            let sidebar = splitView?.arrangedSubviews.first, !sidebar.isHidden
        else { return }
        let width = sidebar.frame.width
        guard width != chosenSidebarWidth else { return }
        chosenSidebarWidth = width
        AppServices.settings.sidebarWidth = Double(width)
        window?.invalidateRestorableState()
    }

    private func start() {
        if let restored = request?.snapshot?.restored(isUsable: { _ in true }) {
            browser.restore(restored.layout, sort: restored.sort, viewMode: restored.viewMode)
        }
        Task { await browser.start() }
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

    /// Follows what the window shows in its title, search field and restorable state,
    /// and shows a failure.
    private func update() {
        let tab = browser.layout.focusedPane.activeTabID
        let title = browser.content(of: tab).folder?.name ?? "Treewise"
        window?.title = title
        toolbarItems.show(title: title, query: browser.content(of: tab).query)
        let snapshot = browser.snapshot
        if lastSnapshot != snapshot { window?.invalidateRestorableState() }
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

    /// The folder, sort order and view, which AppKit keeps beside the frame and tab group.
    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        var snapshot = browser.snapshot
        snapshot.sidebarWidth = chosenSidebarWidth.map(Double.init)
        BrowserWindowRestoration.encode(snapshot, in: state)
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
