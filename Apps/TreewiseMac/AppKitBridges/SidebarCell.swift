import AppKit

/// A sidebar row: an icon and a name, or a section heading without an icon;
/// a volume that can be ejected has an eject button at the end (ADR 0044).
final class SidebarCell: NSTableCellView {
    private static let ejectSize: CGFloat = 16
    /// The room a name keeps from the sidebar's edge before it is cut short, as Finder's.
    private static let edgeMargin: CGFloat = 8

    private let ejectButton = NSButton()
    /// The name stops before the eject button while there is one, else near the edge.
    private var beforeEject: NSLayoutConstraint?
    private var beforeEdge: NSLayoutConstraint?

    /// What the eject button does; `nil` hides it.
    var eject: (() -> Void)? {
        didSet {
            ejectButton.isHidden = eject == nil
            beforeEject?.isActive = eject != nil
            beforeEdge?.isActive = eject == nil
        }
    }

    init(identifier: NSUserInterfaceItemIdentifier, withIcon: Bool, iconSize: NSSize) {
        super.init(frame: .zero)
        self.identifier = identifier
        let text = NSTextField(labelWithString: "")
        text.lineBreakMode = .byTruncatingTail
        text.translatesAutoresizingMaskIntoConstraints = false
        addSubview(text)
        textField = text
        setUpEjectButton()
        beforeEject = text.trailingAnchor.constraint(
            lessThanOrEqualTo: ejectButton.leadingAnchor, constant: -ListMetrics.iconSpacing)
        beforeEdge = text.trailingAnchor.constraint(
            lessThanOrEqualTo: trailingAnchor, constant: -Self.edgeMargin)
        var constraints = [
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            beforeEdge,
        ].compactMap(\.self)
        if withIcon {
            let icon = NSImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            addSubview(icon)
            imageView = icon
            constraints += [
                icon.leadingAnchor.constraint(equalTo: leadingAnchor),
                icon.centerYAnchor.constraint(equalTo: centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: iconSize.width),
                icon.heightAnchor.constraint(equalToConstant: iconSize.height),
                text.leadingAnchor.constraint(
                    equalTo: icon.trailingAnchor, constant: ListMetrics.iconSpacing),
            ]
        } else {
            constraints.append(text.leadingAnchor.constraint(equalTo: leadingAnchor))
        }
        NSLayoutConstraint.activate(constraints)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SidebarCell is created in code only")
    }

    private func setUpEjectButton() {
        ejectButton.image = NSImage(systemSymbolName: "eject", accessibilityDescription: nil)
        ejectButton.isBordered = false
        ejectButton.imagePosition = .imageOnly
        ejectButton.contentTintColor = .secondaryLabelColor
        ejectButton.setAccessibilityLabel(String(localized: "Eject"))
        ejectButton.toolTip = String(localized: "Eject")
        ejectButton.target = self
        ejectButton.action = #selector(ejectClicked)
        ejectButton.isHidden = true
        ejectButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ejectButton)
        NSLayoutConstraint.activate([
            ejectButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            ejectButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            ejectButton.widthAnchor.constraint(equalToConstant: Self.ejectSize),
            ejectButton.heightAnchor.constraint(equalToConstant: Self.ejectSize),
        ])
    }

    @objc private func ejectClicked() {
        eject?()
    }
}
