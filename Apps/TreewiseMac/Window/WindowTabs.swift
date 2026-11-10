import AppKit
import OSLog
import TreewiseCore
import TreewiseUI

/// The folder a window opens at, as a tab or as a window of its own.
struct TabRequest {
    var folder: String
    /// The panes, sort order and view of a tab restored at launch (ADR 0038).
    var snapshot: WindowSnapshot?

    init(folder: FileItem.ID) {
        self.folder = folder.rawValue
    }

    /// A request for a tab as it was before a restart.
    init(restoring window: RestoredWindow) {
        folder = window.layout.focusedPane.activeTab.folder.rawValue
        snapshot = WindowSnapshot(
            layout: window.layout, sort: window.sort, viewMode: window.viewMode)
    }
}

/// Opens browser windows and tabs (ADR 0037, ADR 0081): each is a
/// `BrowserWindowController`, and a tab is a window added to the tab group of
/// the window it was opened from, as macOS's window tabs are. ⌘T, the tab
/// bar's + button, Open in New Tab and ⌘-double-click all come here.
@MainActor
final class WindowTabs {
    static let shared = WindowTabs()
    private static let logger = Logger(subsystem: "me.m-domain.treewise", category: "tabs")

    /// The open browser windows, kept until they close.
    private var controllers: [BrowserWindowController] = []

    /// Opens the first window of a launch, which restores the session before
    /// it (ADR 0038).
    func openFirstWindow() {
        let controller = make(nil)
        controller.open(restoringSession: true)
    }

    /// Opens a window at the start folder: File > New Window (⌘N).
    func openWindow() {
        let controller = make(nil)
        controller.window?.center()
        controller.open(restoringSession: false)
    }

    /// Opens a tab on `folder` beside `window`, or as a window when there is
    /// none; nothing while `window` shows a sheet, as a window with a sheet
    /// waits until it is answered.
    func openTab(at folder: FileItem.ID, beside window: NSWindow?) {
        guard window?.attachedSheet == nil else { return }
        Self.logger.info("Opening a tab beside window \(window?.windowNumber ?? -1)")
        let opened = open(TabRequest(folder: folder))
        guard let window, window !== opened else { return }
        window.addTabbedWindow(opened, ordered: .above)
        opened.makeKeyAndOrderFront(nil)
        Self.logger.info(
            "Window \(opened.windowNumber) joined \(window.windowNumber), \(opened.tabbedWindows?.count ?? 1) tabs"
        )
    }

    /// Opens a window for `request` on its own and returns it.
    @discardableResult
    func open(_ request: TabRequest) -> NSWindow {
        let controller = make(request)
        controller.open(restoringSession: false)
        // A window controller always has the window it was made with.
        return controller.window ?? NSWindow()
    }

    private func make(_ request: TabRequest?) -> BrowserWindowController {
        let controller = BrowserWindowController(request: request)
        controllers.append(controller)
        return controller
    }

    /// Lets go of a window that closed.
    func closed(_ controller: BrowserWindowController) {
        controllers.removeAll { $0 === controller }
    }

    /// The states of every open browser window.
    var allBrowsers: [BrowserState] {
        controllers.map(\.browser)
    }

    /// The state a browser window shows, or `nil` for any other window.
    func browser(of window: NSWindow) -> BrowserState? {
        (window.windowController as? BrowserWindowController)?.browser
    }
}
