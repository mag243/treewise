import AppKit

/// A button that reads as a link, in small text in the link colour, as the overview of
/// proposed names offers its lesser choices; VoiceOver names it a link.
@MainActor
final class LinkButton: NSButton {
    private let run: @MainActor () -> Void

    init(_ title: String, run: @escaping @MainActor () -> Void) {
        self.run = run
        super.init(frame: .zero)
        isBordered = false
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.linkColor,
                .font: NSFont.preferredFont(forTextStyle: .caption1),
            ])
        setAccessibilityRole(.link)
        setAccessibilityLabel(title)
        target = self
        action = #selector(clicked)
        setContentHuggingPriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func clicked() {
        run()
    }
}
