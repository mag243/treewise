import AppKit

/// Makes a pane active on a click in its scroll view outside the list or the
/// icon view, such as below an icon view shorter than the pane (ADR 0022);
/// clicks on the views themselves do so in their `mouseDown`. The recognizer
/// does not delay the click, so selecting and dragging work as before.
@MainActor
final class PaneClickFocus: NSObject {
    private weak var view: NSView?
    private let onClick: () -> Void

    /// Installs the recognizer on `scrollView`; `view` takes the keyboard
    /// focus on a click and `onClick` makes its pane active.
    init(focusing view: NSView, in scrollView: NSScrollView, onClick: @escaping () -> Void) {
        self.view = view
        self.onClick = onClick
        super.init()
        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        recognizer.delaysPrimaryMouseButtonEvents = false
        scrollView.addGestureRecognizer(recognizer)
    }

    @objc private func clicked() {
        guard let view, let window = view.window else { return }
        // A click in a name being edited stays with its editor.
        let editing = (window.firstResponder as? NSView)?.isDescendant(of: view) ?? false
        if !editing || window.firstResponder === view { window.makeFirstResponder(view) }
        onClick()
    }
}
