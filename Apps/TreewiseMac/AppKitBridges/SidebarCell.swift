import AppKit

/// A sidebar row: an icon and a name, or a section heading without an icon;
/// a volume that can be ejected has an eject button at the end (ADR 0044).
final class SidebarCell: NSTableCellView {
    private static let iconSpacing: CGFloat = 6
    private static let ejectSize: CGFloat = 16

    private let ejectButton = NSButton()

    /// What the eject button does; `nil` hides it.
    var eject: (() -> Void)? {
        didSet { ejectButton.isHidden = eject == nil }
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
        var constraints = [
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.trailingAnchor.constraint(
                lessThanOrEqualTo: ejectButton.leadingAnchor, constant: -Self.iconSpacing),
        ]
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
                    equalTo: icon.trailingAnchor, constant: Self.iconSpacing),
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
