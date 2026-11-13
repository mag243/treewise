import AppKit
import OSLog
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// The folder a window opens at, as a tab or as a window of its own.
struct TabRequest {
    var folder: String
    /// The panes, sort order and view of a window restored at launch (ADR 0083).
    var snapshot: WindowSnapshot?

    init(folder: FileItem.ID) {
        self.folder = folder.rawValue
    }

    /// A request for a tab as it was before a restart.
    init(restoring window: RestoredWindow) {
        folder = window.layout.focusedPane.activeTab.folder.rawValue
        var kept = WindowSnapshot(
            layout: window.layout, sort: window.sort, viewMode: window.viewMode)
        kept.sidebarWidth = window.sidebarWidth
        snapshot = kept
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
    /// Where the next new window's top left corner goes, as AppKit cascades
    /// windows; zero until the first window is placed.
    private var cascadePoint = NSPoint.zero

    /// Opens a window at the start folder when AppKit restored none: at
    /// launch, after AppKit brought back the windows before it (ADR 0083).
    func openWindowIfNoneRestored() {
        guard controllers.isEmpty else { return }
        openWindow()
    }

    /// Opens a window at the start folder: File > New Window (⌘N).
    func openWindow() {
        let controller = make(nil)
        place(controller.window)
        controller.open()
    }

    /// A window as it was before a restart, for AppKit to put back: at the
    /// start folder when none of its folders can be shown any more.
    func restore(_ snapshot: WindowSnapshot?) -> NSWindow {
        let reader = LocalFileSystem(locations: LaunchOptions.locations)
        let restored = snapshot?.restored { (try? reader.currentItem(at: $0))?.isContainer == true }
        let controller = make(restored.map(TabRequest.init(restoring:)))
        controller.openRestored()
        Self.logger.info(
            "Restored a window, \(restored == nil ? "at the start folder" : "as it was")")
        // A window controller always has the window it was made with.
        return controller.window ?? NSWindow()
    }

    /// Puts the first window in the middle of the main screen, the one with
    /// the menu bar or the key window, and each later one a step down and to
    /// the right of the one before. `center()` takes the screen the window
    /// happens to be on, which need not be the one the user works on.
    private func place(_ window: NSWindow?) {
        guard let window else { return }
        if cascadePoint == .zero, let screen = NSScreen.main?.visibleFrame {
            window.setFrameOrigin(
                NSPoint(
                    x: screen.midX - window.frame.width / 2,
                    y: screen.midY - window.frame.height / 2))
        }
        cascadePoint = window.cascadeTopLeft(from: cascadePoint)
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
        controller.open()
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
