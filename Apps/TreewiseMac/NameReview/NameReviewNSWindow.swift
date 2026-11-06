import AppKit
import Quartz

/// The review's window, which answers for Quick Look while it is key, so Space on a row
/// shows its file as Space in the file list does. The rows are SwiftUI, which has no
/// responder of its own for the panel to ask.
final class NameReviewNSWindow: NSWindow {
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel?) -> Bool {
        true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel?) {
        // AppKit calls this on the main thread, as it does every responder method.
        MainActor.assumeIsolated { panel?.dataSource = QuickLookSource.shared }
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel?) {
        MainActor.assumeIsolated { panel?.dataSource = nil }
    }
}
