import AppKit

/// A menu item that runs a closure, so a menu can be built from actions.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    /// `symbol` is the SF Symbol beside the title, the same one the command bar uses for
    /// that action; nil for an item without one.
    init(
        _ title: String, symbol: String? = nil, enabled: Bool = true,
        handler: @escaping () -> Void
    ) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        if let symbol {
            show(NSImage(systemSymbolName: symbol, accessibilityDescription: nil))
        }
        target = self
        isEnabled = enabled
    }

    /// Shows `image` beside the title.
    func show(_ image: NSImage?) {
        self.image = image
        // macOS 27 hides a menu item's image unless asked; CI's older Xcode
        // does not know the property (ADR 0012, ADR 0052).
        #if compiler(>=6.4)
            if #available(macOS 27, *) { preferredImageVisibility = .visible }
        #endif
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("ClosureMenuItem is made in code only")
    }

    @objc private func run() {
        handler()
    }
}
