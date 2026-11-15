import AppKit

/// A list in a Settings pane, as the Names tab's Name Patterns has it: a table without a
/// header in the full-width style, in a scroll view with a bezel, as wide as the pane
/// between its margins, as the Add-ons tab's cards are. Every list in Settings is made
/// here, so they look alike; the UI review checks it (ADR 0103).
@MainActor
enum SettingsList {
    /// The width of a list and of what goes with it in a pane: the pane's between its
    /// margins.
    static let width = SettingsWindow.paneSize.width - 2 * SettingsForm.margin

    /// `table`, or an outline, in its scroll view.
    static func scroll(_ table: NSTableView, height: CGFloat) -> NSScrollView {
        table.headerView = nil
        table.style = .fullWidth
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalToConstant: width),
            scroll.heightAnchor.constraint(equalToConstant: height),
        ])
        return scroll
    }

    /// A section's heading, as Name Patterns.
    static func heading(_ title: String) -> NSTextField {
        let heading = NSTextField(labelWithString: title)
        heading.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        return heading
    }

    /// A heading inside a section, small and grey, as the Add-ons tab's Reading.
    static func subheading(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    /// A note in small grey text, as the one under Name Patterns; every note in Settings
    /// has this style.
    static func note(_ text: String, width: CGFloat = width) -> NSTextField {
        let note = NSTextField(wrappingLabelWithString: text)
        note.font = .preferredFont(forTextStyle: .caption1)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = width
        note.setContentCompressionResistancePriority(.required, for: .vertical)
        return note
    }

    /// A pane of the Settings window's size with `stack` in the middle, a margin from its
    /// top; with `fillsHeight` the stack also reaches down to a margin from its bottom.
    static func pane(_ stack: NSStackView, fillsHeight: Bool = false) -> NSView {
        stack.translatesAutoresizingMaskIntoConstraints = false
        let size = SettingsWindow.paneSize
        let pane = NSView(frame: NSRect(origin: .zero, size: size))
        pane.addSubview(stack)
        NSLayoutConstraint.activate([
            pane.widthAnchor.constraint(equalToConstant: size.width),
            pane.heightAnchor.constraint(equalToConstant: size.height),
            stack.topAnchor.constraint(equalTo: pane.topAnchor, constant: SettingsForm.margin),
            stack.centerXAnchor.constraint(equalTo: pane.centerXAnchor),
        ])
        if fillsHeight {
            stack.bottomAnchor.constraint(
                equalTo: pane.bottomAnchor, constant: -SettingsForm.margin
            ).isActive = true
        }
        return pane
    }
}
