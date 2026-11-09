import AppKit
import Quartz
import os

/// What Quick Look shows: the selected files of the list or the icon view
/// whose turn it is. Space shows and hides the panel; while it is shown, it
/// follows the selection, as in Finder.
@MainActor
final class QuickLookSource: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLookSource()

    /// The files shown; the panel asks for them outside the main actor.
    private nonisolated let shown = OSAllocatedUnfairLock(initialState: [URL]())
    private var followRequest = 0

    /// Shows the panel with `urls`, or hides it when it is shown.
    func toggle(_ urls: [URL]) {
        let panel: QLPreviewPanel = QLPreviewPanel.shared()
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            shown.withLock { $0 = urls }
            panel.makeKeyAndOrderFront(nil)
        }
    }

    /// Shows the panel with what `urls` gives, or hides it when it is shown.
    /// An entry of an archive is extracted only when the panel is to show it.
    func toggle(_ urls: @escaping () async -> [URL]) {
        guard !isShown else {
            QLPreviewPanel.shared().orderOut(nil)
            return
        }
        Task { toggle(await urls()) }
    }

    /// Shows what `urls` gives instead, when the panel is shown. Of requests
    /// that overlap, the last one counts.
    func follow(_ urls: @escaping () async -> [URL]) {
        guard isShown else { return }
        followRequest += 1
        let request = followRequest
        Task {
            let found = await urls()
            if request == followRequest { follow(found) }
        }
    }

    private var isShown: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
    }

    /// Shows `urls` instead, when the panel is shown.
    func follow(_ urls: [URL]) {
        guard QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().isVisible,
            urls != shown.withLock({ $0 })
        else { return }
        shown.withLock { $0 = urls }
        QLPreviewPanel.shared().reloadData()
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel?) -> Int {
        shown.withLock { $0.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel?, previewItemAt index: Int)
        -> (any QLPreviewItem)?
    {
        let urls = shown.withLock { $0 }
        return urls.indices.contains(index) ? urls[index] as NSURL : nil
    }
}
