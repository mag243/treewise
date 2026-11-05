import AppKit
import OSLog
import SwiftUI
import TreewiseCore
import TreewiseUI

/// The folder a window opened as a tab starts at. Each request is unique, so
/// SwiftUI opens a new window for it instead of bringing an existing one forward.
struct TabRequest: Codable, Hashable {
    var id = UUID()
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

    /// Requests are the same only when they are one request.
    static func == (lhs: TabRequest, rhs: TabRequest) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Opens tabs as macOS window tabs (ADR 0037): a new window on a folder,
/// added to the tab group of the window it was opened from. ⌘T, the tab
/// bar's + button, Open in New Tab and ⌘-double-click all come here, since a
/// SwiftUI `WindowGroup` has no New Tab of its own.
@MainActor
final class WindowTabs {
    static let shared = WindowTabs()
    private static let logger = Logger(subsystem: "me.m-domain.treewise", category: "tabs")

    /// Opens a window of the window group; each browser window hands it over.
    var openWindow: OpenWindowAction?
    /// The window each open request's new window joins as a tab.
    private var parents: [UUID: NSWindow] = [:]
    /// Who waits for the window of an open request, by `open(_:)`.
    private var waiting: [UUID: CheckedContinuation<NSWindow, Never>] = [:]
    /// The state each browser window shows; `nil` once it is gone.
    private let browsers = NSMapTable<NSWindow, Entry>.weakToStrongObjects()

    /// Opens a tab on `folder` beside `window`, or as a window when there is
    /// none; nothing while `window` shows a sheet, which AppKit then fails to
    /// lay out and crashes on.
    func openTab(at folder: FileItem.ID, beside window: NSWindow?) {
        guard window?.attachedSheet == nil else { return }
        let request = TabRequest(folder: folder)
        parents[request.id] = window
        Self.logger.info("Opening a tab beside window \(window?.windowNumber ?? -1)")
        openWindow?(value: request)
    }

    /// Opens a tab on the folder `window` shows: the + button of its tab bar.
    func openTab(besideWindowOf window: NSWindow?) {
        guard let window, let browser = browser(of: window) else { return }
        openTab(at: browser.layout.focusedPane.activeTab.folder, beside: window)
    }

    /// Opens a window for `request` on its own and returns it once it is
    /// shown; `nil` when no browser window has handed over `openWindow` yet.
    func open(_ request: TabRequest) async -> NSWindow? {
        guard let openWindow else { return nil }
        return await withCheckedContinuation { continuation in
            waiting[request.id] = continuation
            openWindow(value: request)
        }
    }

    /// The states of every open browser window.
    var allBrowsers: [BrowserState] {
        NSApp.windows.compactMap { browser(of: $0) }
    }

    /// The state a browser window shows, or `nil` for any other window.
    func browser(of window: NSWindow) -> BrowserState? {
        browsers.object(forKey: window)?.browser
    }

    /// Records the window a browser window is in: it joins the tab group it was
    /// requested for, and whoever waits for it in `open(_:)` gets it.
    func attach(_ window: NSWindow, for request: TabRequest?, browser: BrowserState) {
        browsers.setObject(Entry(browser: browser), forKey: window)
        guard let request else {
            Self.logger.info("Window \(window.windowNumber) attached without a request")
            return
        }
        let waiter = waiting.removeValue(forKey: request.id)
        Self.logger.info(
            "Window \(window.windowNumber) attached, \(waiter == nil ? "not awaited" : "awaited", privacy: .public)"
        )
        waiter?.resume(returning: window)
        guard let parent = parents.removeValue(forKey: request.id), parent !== window else {
            return
        }
        parent.addTabbedWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(nil)
        Self.logger.info(
            "Window \(window.windowNumber) joined \(parent.windowNumber), \(window.tabbedWindows?.count ?? 1) tabs"
        )
    }

    /// A browser window's state, held weakly, as an object `NSMapTable` can hold.
    private final class Entry {
        weak var browser: BrowserState?

        init(browser: BrowserState) {
            self.browser = browser
        }
    }
}
