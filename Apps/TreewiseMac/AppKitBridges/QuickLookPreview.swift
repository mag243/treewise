import Quartz
import SwiftUI
import TreewiseCore

/// A Quick Look preview of one file, as the details pane shows it (M5b).
struct QuickLookPreview: NSViewRepresentable {
    let item: FileItem.ID

    func makeNSView(context: Context) -> QLPreviewView {
        // `.compact` leaves out the controls of the full Quick Look panel.
        let view = QLPreviewView(frame: .zero, style: .compact) ?? QLPreviewView()
        view.autostarts = true
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        let url = URL(fileURLWithPath: item.rawValue) as NSURL
        if (view.previewItem as? NSURL) != url { view.previewItem = url }
    }

    static func dismantleNSView(_ view: QLPreviewView, coordinator: ()) {
        view.close()
    }
}
