import AppKit
import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseModuleXPC
import TreewiseUI

/// Opens the overview of proposed names in a window of its own, so the folder stays
/// usable behind it (ADR 0057).
@MainActor
enum NameReviewWindow {
    private static let defaultSize = NSSize(width: 980, height: 620)
    private static let minimumSize = NSSize(width: 720, height: 420)
    /// One connection to the modules' service, for every review.
    private static let host = XPCModuleHost()
    private static let store = FolderSettingsStore(directory: FolderSettingsStore.defaultDirectory)
    /// The open windows, kept until they close.
    private static var open: [Open] = []

    private struct Open {
        let window: NSWindow
        let closer: NameReviewWindowCloser
    }

    /// Opens a review of the browser's selection, or of its folder's files.
    static func show(for browser: BrowserState, undoManager: UndoManager?) {
        Task {
            guard let model = await browser.makeNameReview(host: host, store: store) else { return }
            present(model, browser: browser, undoManager: undoManager)
            await model.start()
        }
    }

    private static func present(
        _ model: NameReviewModel, browser: BrowserState, undoManager: UndoManager?
    ) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
            defer: false)
        window.title = String(localized: "Suggest Names: \(model.folder.name)")
        window.minSize = minimumSize
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.contentViewController = NSHostingController(
            rootView: NameReviewView(
                model: model, browser: browser, undoManager: undoManager,
                close: { [weak window] in window?.close() }))
        window.center()
        let closing = NameReviewWindowCloser(model: model) { window in
            open.removeAll { $0.window === window }
        }
        window.delegate = closing
        open.append(.init(window: window, closer: closing))
        window.makeKeyAndOrderFront(nil)
    }
}

/// Stops a review's reading when its window closes.
@MainActor
final class NameReviewWindowCloser: NSObject, NSWindowDelegate {
    /// Long enough for SwiftUI to take the preview away after the window closed.
    private static let previewTeardownDelay: TimeInterval = 1

    private let model: NameReviewModel
    private let onClose: (NSWindow) -> Void

    init(model: NameReviewModel, onClose: @escaping (NSWindow) -> Void) {
        self.model = model
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        model.stop()
        // Quick Look aborts the app when its preview goes away with a window that is
        // already released. So the preview leaves first, while the window still exists.
        model.isClosing = true
        guard let window = notification.object as? NSWindow else { return }
        let onClose = onClose
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.previewTeardownDelay) {
            MainActor.assumeIsolated { onClose(window) }
        }
    }
}
