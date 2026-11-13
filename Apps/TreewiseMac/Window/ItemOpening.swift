import AppKit
import TreewiseCore
import TreewiseUI

/// Opens items as a double-click or ⌘↓ does (ADR 0022): folders in the browser,
/// where `placement` says; links to folders as folders; files in their app.
@MainActor
enum ItemOpening {
    /// Opens `items` from a pane. One item opens where `placement` says; of
    /// several, each folder opens in a new tab. A new tab is a window tab, and
    /// the other pane is the other window (ADR 0037).
    static func open(
        _ items: [FileItem], from pane: Int, in placement: OpenPlacement, browser: BrowserState
    ) async {
        let placement = items.count == 1 ? placement : .newTab
        for item in items {
            if placement == .newTab, let place = browser.placeToOpen(for: item) {
                WindowTabs.shared.openTab(at: place, beside: NSApp.keyWindow)
                continue
            }
            if placement == .otherPane, let place = browser.placeToOpen(for: item) {
                await WindowTabs.shared.openInOtherWindow(place, from: NSApp.keyWindow)
                continue
            }
            guard case .openFile(let file) = await browser.open(item, pane: pane, in: placement)
            else { continue }
            if file.id.isInsideArchive {
                for copy in await browser.previewURLs(for: [file]) {
                    FileOpener.openInDefaultApp(copy)
                }
            } else if let folder = FileOpener.linkedFolder(of: file) {
                await browser.navigate(pane: pane, to: folder)
            } else {
                FileOpener.open(file)
            }
        }
    }
}
