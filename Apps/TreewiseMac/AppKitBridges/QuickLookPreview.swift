import AppKit
import SwiftUI
import TreewiseCore

/// A `QuickLookView` in a SwiftUI view, for the overview of proposed names.
struct QuickLookPreview: NSViewRepresentable {
    let item: FileItem.ID

    func makeNSView(context: Context) -> QuickLookView {
        QuickLookView()
    }

    func updateNSView(_ view: QuickLookView, context: Context) {
        view.show(item)
    }
}
