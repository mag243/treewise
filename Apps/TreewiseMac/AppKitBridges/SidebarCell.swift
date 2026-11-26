import AppKit
import TreewiseCore

/// A sidebar row: an icon and a name, or a section heading without an icon;
/// a volume that can be ejected has an eject button at the end (ADR 0044), and a git
/// repository's top folder a small mark there; a folder inside a repository shows its
/// state on its icon, as in the list (ADR 0149).
final class SidebarCell: NSTableCellView {
    private static let ejectSize: CGFloat = 16
    private static let markSize: CGFloat = 11
    /// The git badge's side, as in the list.
    private static let badgeSide: CGFloat = 9
    /// The room a name keeps from the sidebar's edge before it is cut short, as Finder's.
    private static let edgeMargin: CGFloat = 8

    private let ejectButton = NSButton()
    private let repositoryMark = NSImageView()
    private let gitBadge = GitBadgeView()
    /// The mark and the eject button, at the row's end.
    private let accessories = NSStackView()
    /// The name stops before the accessories while there are some, else near the edge.
    private var beforeEject: NSLayoutConstraint?
    private var beforeEdge: NSLayoutConstraint?

    /// What the eject button does; `nil` hides it.
    var eject: (() -> Void)? {
        didSet {
            ejectButton.isHidden = eject == nil
            placeName()
        }
    }

    /// Whether the row's folder is a git repository's top folder.
    var marksRepository = false {
        didSet {
            repositoryMark.isHidden = !marksRepository
            placeName()
        }
    }

    /// The git state of the row's folder; `nil` shows none (ADR 0149).
    var gitState: GitItemState? {
        didSet {
            gitBadge.state = gitState
            imageView?.alphaValue = GitIconLook.alpha(for: gitState)
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
        setUpRepositoryMark()
        setUpAccessories()
        beforeEject = text.trailingAnchor.constraint(
            lessThanOrEqualTo: accessories.leadingAnchor, constant: -ListMetrics.iconSpacing)
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
        if let icon = imageView {
            GitIconLook.place(gitBadge, on: icon, side: Self.badgeSide, in: self)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SidebarCell is created in code only")
    }

    private func placeName() {
        let hasAccessory = eject != nil || marksRepository
        // Deactivated first, so the two never hold at once.
        beforeEject?.isActive = false
        beforeEdge?.isActive = false
        (hasAccessory ? beforeEject : beforeEdge)?.isActive = true
    }

    private func setUpRepositoryMark() {
        repositoryMark.image = NSImage(
            systemSymbolName: "arrow.triangle.branch",
            accessibilityDescription: String(localized: "Git repository"))
        repositoryMark.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: Self.markSize, weight: .regular)
        repositoryMark.contentTintColor = .secondaryLabelColor
        repositoryMark.toolTip = String(localized: "Git repository")
        repositoryMark.isHidden = true
    }

    private func setUpAccessories() {
        accessories.orientation = .horizontal
        // A hidden eject button or mark takes no room, so the name runs up to what shows.
        accessories.detachesHiddenViews = true
        accessories.spacing = ListMetrics.iconSpacing
        accessories.setViews([repositoryMark, ejectButton], in: .trailing)
        accessories.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accessories)
        NSLayoutConstraint.activate([
            accessories.trailingAnchor.constraint(equalTo: trailingAnchor),
            accessories.centerYAnchor.constraint(equalTo: centerYAnchor),
            ejectButton.widthAnchor.constraint(equalToConstant: Self.ejectSize),
            ejectButton.heightAnchor.constraint(equalToConstant: Self.ejectSize),
        ])
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
    }

    @objc private func ejectClicked() {
        eject?()
    }
}
