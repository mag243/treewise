import AppKit

/// A list in a Settings pane, as the Names tab's Name Patterns has it: a table without a
/// header in the full-width style, in a scroll view with a bezel, `width` wide and
/// `height` tall. Every list in Settings is made here, so they look alike.
@MainActor
enum SettingsList {
    /// The width of a list and of what goes with it in a pane.
    static let width: CGFloat = 440

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

    /// A note in small grey text under a list, as the one under Name Patterns.
    static func note(_ text: String) -> NSTextField {
        let note = NSTextField(wrappingLabelWithString: text)
        note.font = .preferredFont(forTextStyle: .caption1)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = width
        return note
    }
}
