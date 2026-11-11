import Quartz
import TreewiseCore

/// A Quick Look preview of one file, as the details pane and the overview of
/// proposed names show it (M5b, ADR 0057). Quick Look aborts the app when a
/// closed preview is handed an item, so the preview is closed only here: when
/// the view leaves its window, after which a new one is made should it return,
/// and when its window closes, after which it previews nothing.
@MainActor
final class QuickLookView: NSView {
    private var preview: QLPreviewView?
    private var item: FileItem.ID?
    private var isClosed = false
    private var windowWillClose: (any NSObjectProtocol)?

    /// Previews `item`.
    func show(_ item: FileItem.ID) {
        self.item = item
        showItem()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowWillClose.map(NotificationCenter.default.removeObserver)
        windowWillClose = nil
        guard let window else { return closePreview() }
        windowWillClose = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isClosed = true
                self?.closePreview()
            }
        }
        showItem()
    }

    private func showItem() {
        guard !isClosed, window != nil, let url = item?.diskURL as NSURL? else { return }
        let preview = preview ?? makePreview()
        if (preview.previewItem as? NSURL) != url { preview.previewItem = url }
    }

    private func makePreview() -> QLPreviewView {
        // `.compact` leaves out the controls of the full Quick Look panel.
        let preview = QLPreviewView(frame: bounds, style: .compact) ?? QLPreviewView()
        preview.autostarts = true
        preview.shouldCloseWithWindow = false
        preview.autoresizingMask = [.width, .height]
        addSubview(preview)
        self.preview = preview
        return preview
    }

    private func closePreview() {
        preview?.close()
        preview?.removeFromSuperview()
        preview = nil
    }
}
