import AppKit
import TreewiseCore
import os

/// Help > Acknowledgements: the licences of the parts Treewise uses, such as Sparkle's,
/// which go with every copy of the app. The text is `Acknowledgements.txt` in the app,
/// in English, as licences are.
@MainActor
final class AcknowledgementsWindow: NSObject {
    static let shared = AcknowledgementsWindow()

    private static let size = NSSize(width: 560, height: 520)
    private static let inset = NSSize(width: 16, height: 16)
    private static let logger = Logger(
        subsystem: LogSubsystem.name, category: "Acknowledgements")

    private var window: NSWindow?

    @objc func showAcknowledgements(_ sender: Any?) {
        let window = window ?? makeWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: true)
        window.title = String(localized: "Acknowledgements")
        window.isReleasedWhenClosed = false
        let scroll = NSTextView.scrollableTextView()
        if let text = scroll.documentView as? NSTextView {
            text.isEditable = false
            text.textContainerInset = Self.inset
            text.font = .monospacedSystemFont(
                ofSize: NSFont.smallSystemFontSize, weight: .regular)
            text.string = Self.text()
            text.setAccessibilityIdentifier("acknowledgements")
        }
        window.contentView = scroll
        window.center()
        return window
    }

    private static func text() -> String {
        guard let url = Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            logger.error("Acknowledgements.txt is missing from the app")
            return ""
        }
        return text
    }
}
