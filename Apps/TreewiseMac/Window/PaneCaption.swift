import AppKit

/// The slim caption at the top of each half of a split window: its folder's name, and on
/// the active half a line in the accent colour above it and the name in the label colour,
/// so the half the toolbar, the command bar and the address bar act on is plain to see
/// (ADR 0154). A window that is not split shows none.
@MainActor
final class PaneCaption: NSView {
    private static let lineHeight: CGFloat = 2
    private static let padding: CGFloat = 3
    private static let sidePadding: CGFloat = 10
    private static let fontSize = NSFont.smallSystemFontSize

    private let name = NSTextField(labelWithString: "")
    private let line = NSBox()
    private let separator = NSBox()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(false)
        name.lineBreakMode = .byTruncatingMiddle
        name.setAccessibilityIdentifier("paneCaption")
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        line.boxType = .custom
        line.borderWidth = 0
        line.fillColor = .controlAccentColor
        separator.boxType = .separator
        for view in [line, name, separator] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: topAnchor),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: Self.lineHeight),
            name.topAnchor.constraint(equalTo: line.bottomAnchor, constant: Self.padding),
            name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.sidePadding),
            name.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.sidePadding),
            separator.topAnchor.constraint(equalTo: name.bottomAnchor, constant: Self.padding),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Shows the half's folder, as the active half or not.
    func show(folder: String, isActive: Bool) {
        if name.stringValue != folder { name.stringValue = folder }
        name.font =
            isActive
            ? .boldSystemFont(ofSize: Self.fontSize) : .systemFont(ofSize: Self.fontSize)
        name.textColor = isActive ? .labelColor : .secondaryLabelColor
        line.fillColor = isActive ? .controlAccentColor : .clear
    }
}
