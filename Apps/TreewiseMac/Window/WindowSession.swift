import AppKit
import OSLog
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// Saves the windows and their tabs, and restores them in the first window of
/// the next launch (ADR 0038).
@MainActor
enum WindowSession {
    private static let logger = Logger(subsystem: "me.m-domain.treewise", category: "session")
    private static var isClaimed = false
    /// While a session is restored, saving waits, so a half-restored one is not kept.
    private static var isRestoring = false
    /// Where the session is kept, from the first browser window.
    private static var settings: BrowserSettings?
    /// Once Treewise is quitting, windows that close do not shrink the session.
    private static var isQuitting = false
    /// The browser windows the session holds.
    private static var openWindows = OpenWindows<NSWindow>()

    /// Saves the session to `settings` from now on: on every change, when a
    /// window closes and when Treewise quits.
    static func watch(_ settings: BrowserSettings) {
        guard self.settings == nil else { return }
        self.settings = settings
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { notification in
            guard let closing = notification.object as? NSWindow else { return }
            MainActor.assumeIsolated { close(closing) }
        }
    }

    /// Records that a browser window shows a folder, so the session holds it.
    static func open(_ window: NSWindow) {
        openWindows.open(window)
    }

    /// Leaves a closing window out of the session from now on, and saves.
    private static func close(_ window: NSWindow) {
        logger.info("Window \(window.windowNumber) closes")
        openWindows.close(window)
        save()
    }

    /// The tab groups to restore, for the first window of a launch, with only
    /// the folders that can still be shown inside the boundary and one folder
    /// per tab; empty for every later window.
    static func claim(from settings: BrowserSettings) -> [RestoredGroup] {
        guard !isClaimed else { return [] }
        isClaimed = true
        let reader = LocalFileSystem(locations: LaunchOptions.locations)
        let groups =
            settings.lastSession?.restored {
                (try? reader.currentItem(at: $0))?.isContainer == true
            }.map { $0.oneFolderPerTab() } ?? []
        isRestoring = !groups.isEmpty
        logger.info(
            "Claimed a session of \(groups.count) groups: \(tabCounts(groups.map(\.tabs.count)), privacy: .public)"
        )
        return groups
    }

    /// Opens every restored tab but the first, which `window` shows: the first
    /// group's other tabs beside it, every other group as a window with its
    /// tabs. Then each group shows its selected tab, and the first group is in front.
    static func restore(_ groups: [RestoredGroup], after window: NSWindow) {
        defer {
            isRestoring = false
            logger.info("Restored the session")
        }
        var fronts: [NSWindow] = []
        for (index, group) in groups.enumerated() {
            var tabs = index == 0 ? [window] : []
            for tab in group.tabs.dropFirst(tabs.count) {
                logger.info("Group \(index): opening tab \(tabs.count)")
                let opened = WindowTabs.shared.open(TabRequest(restoring: tab))
                tabs.last?.addTabbedWindow(opened, ordered: .above)
                tabs.append(opened)
                logger.info(
                    "Group \(index): window \(opened.windowNumber) joined, \(opened.tabbedWindows?.count ?? 1) tabs"
                )
            }
            guard !tabs.isEmpty else { continue }
            let selected = tabs[min(group.selectedTab, tabs.count - 1)]
            selected.tabGroup?.selectedWindow = selected
            fronts.append(selected)
        }
        for front in fronts.reversed() { front.orderFront(nil) }
        fronts.first?.makeKeyAndOrderFront(nil)
    }

    /// Saves the open browser windows from front to back.
    static func save() {
        guard !isRestoring, !isQuitting, let settings else {
            logger.debug("Not saved: restoring \(isRestoring), quitting \(isQuitting)")
            return
        }
        let session = session()
        settings.lastSession = session
        logger.info(
            "Saved \(session.groups.count) groups: \(tabCounts(session.groups.map(\.tabs.count)), privacy: .public)"
        )
    }

    /// The number of tabs per group, for the log: "3, 1".
    private static func tabCounts(_ counts: [Int]) -> String {
        counts.map(String.init).joined(separator: ", ")
    }

    /// Saves the session a last time as Treewise quits, before any window closes.
    static func saveForQuitting() {
        logger.info("Quitting")
        save()
        isQuitting = true
    }

    private static func session() -> SessionSnapshot {
        let groups = openWindows.groups(frontToBack: NSApp.orderedWindows) {
            $0.tabbedWindows ?? [$0]
        }
        return SessionSnapshot(
            groups: groups.compactMap { tabs in
                let kept = tabs.compactMap { tab in
                    WindowTabs.shared.browser(of: tab).map { (tab, $0) }
                }
                guard !kept.isEmpty else { return nil }
                let selected = tabs.first?.tabGroup?.selectedWindow
                return SessionSnapshot.Group(
                    tabs: kept.map(\.1.snapshot),
                    selectedTab: kept.firstIndex { $0.0 === selected } ?? 0)
            })
    }
}
