import Quartz
import SwiftUI
import TreewiseCore
import TreewiseUI

/// A Quick Look preview of one file, as the details pane and the overview of proposed
/// names show it (M5b, ADR 0057).
struct QuickLookPreview: NSViewRepresentable {
    let item: FileItem.ID

    /// Whether the view is closed. Quick Look aborts the app when a closed view is handed
    /// an item, and a closed view reports no item, so it would otherwise be handed one again.
    final class Coordinator {
        var isClosed = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> QLPreviewView {
        // `.compact` leaves out the controls of the full Quick Look panel.
        let view = QLPreviewView(frame: .zero, style: .compact) ?? QLPreviewView()
        view.autostarts = true
        // Quick Look would close the view with its window, unseen by SwiftUI, which can
        // still update it. It is closed in `dismantleNSView` instead.
        view.shouldCloseWithWindow = false
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        guard !context.coordinator.isClosed, let url = item.diskURL as NSURL? else { return }
        if (view.previewItem as? NSURL) != url { view.previewItem = url }
    }

    static func dismantleNSView(_ view: QLPreviewView, coordinator: Coordinator) {
        coordinator.isClosed = true
        view.close()
    }
}
