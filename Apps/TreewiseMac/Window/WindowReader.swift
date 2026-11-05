import AppKit
import SwiftUI

/// Reports the `NSWindow` a SwiftUI view is in, once it is in one.
struct WindowReader: NSViewRepresentable {
    let onWindow: @MainActor (NSWindow) -> Void

    func makeNSView(context: Context) -> ReportingView {
        ReportingView(onWindow: onWindow)
    }

    func updateNSView(_ view: ReportingView, context: Context) {}

    final class ReportingView: NSView {
        private let onWindow: @MainActor (NSWindow) -> Void

        init(onWindow: @escaping @MainActor (NSWindow) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindow(window) }
        }
    }
}
