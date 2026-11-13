import AppKit
import TreewiseCore
import TreewiseModuleInterface
import TreewiseUI
import UniformTypeIdentifiers

/// One add-on in Settings' Add-ons tab, as a card (ADR 0092): a header with its icon, name,
/// what it reads and for which files, its licence as a badge and an on/off switch; and,
/// when it is the selected card, a body with its summary, what it recognizes, its trial
/// or purchase, and On in new folders.
@MainActor
final class AddOnCardView: NSView {
    /// What the card's controls do.
    struct Actions {
        let turnOn: @MainActor (Bool) -> Void
        let turnOnInNewFolders: @MainActor (Bool) -> Void
        let startTrial: @MainActor () -> Void
    }

    private static let padding = NSSize(width: 12, height: 9)
    private static let iconSize: CGFloat = 26
    private static let iconRadius: CGFloat = 6
    private static let iconInset: CGFloat = 4
    private static let headerSpacing: CGFloat = 10
    private static let bodySpacing: CGFloat = 8
    private static let selectedEdge: CGFloat = 2
    /// The body starts under the name, past the icon.
    private static var bodyIndent: CGFloat { iconSize + headerSpacing }

    private let module: NameModuleDescription
    private let card: AddOnCard
    private let licence: ModuleLicenceState?
    private let actions: Actions

    /// Builds the card at `width`, open when `isSelected`.
    init(
        module: NameModuleDescription, card: AddOnCard, licence: ModuleLicenceState?,
        isSelected: Bool, isOnInNewFolders: Bool, width: CGFloat, actions: Actions
    ) {
        self.module = module
        self.card = card
        self.licence = licence
        self.actions = actions
        super.init(frame: .zero)
        let box = AddOnCardStyle.group(
            fill: AddOnCardStyle.cardFill,
            border: isSelected ? .controlAccentColor : .separatorColor,
            radius: AddOnCardStyle.cardRadius, borderWidth: isSelected ? Self.selectedEdge : 1)
        box.contentViewMargins = Self.padding
        let inner = width - 2 * Self.padding.width
        let header = header()
        header.widthAnchor.constraint(equalToConstant: inner).isActive = true
        var rows: [NSView] = [header]
        if isSelected {
            rows.append(body(isOnInNewFolders: isOnInNewFolders, width: inner - Self.bodyIndent))
        }
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.bodySpacing
        Self.fill(box.contentView, with: stack)
        Self.fill(self, with: box)
        widthAnchor.constraint(equalToConstant: width).isActive = true
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(NameReviewText.name(of: module))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// The add-on symbol on a tile of the accent colour: an add-on has no icon of its own.
    private static func icon() -> NSView {
        let icon = AddOnCardStyle.group(
            fill: .controlAccentColor, border: .clear, radius: iconRadius)
        let symbol = NSImageView(
            image: NSImage(
                systemSymbolName: "puzzlepiece.extension.fill", accessibilityDescription: nil)
                ?? NSImage())
        symbol.contentTintColor = .white
        fill(icon.contentView, with: symbol, inset: iconInset)
        icon.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
        return icon
    }

    private func header() -> NSView {
        let name = NSTextField(labelWithString: NameReviewText.name(of: module))
        name.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let reads = Self.caption(
            Self.reads(module) + " · " + String(localized: "For \(Self.files(module))"))
        let titles = NSStackView(views: [name, reads])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 1
        titles.setContentHuggingPriority(.defaultLow, for: .horizontal)
        var views: [NSView] = [Self.icon(), titles]
        if let badge = badge() { views.append(badge) }
        let toggle = ClosureSwitch(label: NameReviewText.name(of: module), change: actions.turnOn)
        toggle.state = card.isOn ? .on : .off
        toggle.isEnabled = card.canSwitch
        if card.isOn, !card.canSwitch {
            toggle.toolTip = String(localized: "At least one add-on stays on")
        }
        // The name at the leading edge, the badge and the switch at the trailing one.
        let header = NSStackView()
        header.setViews(Array(views.prefix(2)), in: .leading)
        header.setViews(Array(views.dropFirst(2)) + [toggle], in: .trailing)
        header.spacing = Self.headerSpacing
        header.alignment = .centerY
        return header
    }

    /// Free for a free add-on, a paid one's licence; none for a paid one whose licence
    /// could not be read.
    private func badge() -> NSView? {
        let text: String
        if module.isFree {
            text = String(localized: "Free")
        } else if let licence {
            text = LicenceText.state(licence)
        } else {
            return nil
        }
        let label = Self.caption(text)
        let color = AddOnCardStyle.color(of: card.tone)
        label.textColor = color
        label.font = .systemFont(
            ofSize: NSFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .semibold)
        return AddOnCardStyle.pill(label, color: color)
    }

    private func body(isOnInNewFolders: Bool, width: CGFloat) -> NSView {
        var views: [NSView] = []
        if let summary = module.summary(preferring: Locale.preferredLanguages) {
            let line = NSTextField(wrappingLabelWithString: summary)
            line.preferredMaxLayoutWidth = width
            views.append(line)
        }
        // What it finds in a folder's names tells add-ons apart (ADR 0088).
        if !module.recognizes.isEmpty {
            views.append(Self.caption(String(localized: "Recognizes")))
            let fields = module.recognizes.map {
                RecognizedField($0, today: Date(), calendar: .current)
            }
            views.append(RecognizedFieldsView(fields, width: width))
            views.append(AddOnCardStyle.legend())
        }
        if let offer = Self.offer(module, licence: licence, startTrial: actions.startTrial) {
            views.append(offer)
        }
        if card.canSwitch || card.isOn {
            let newFolders = ClosureSwitch(
                label: String(localized: "On in new folders"), change: actions.turnOnInNewFolders)
            newFolders.state = card.isOn && isOnInNewFolders ? .on : .off
            newFolders.isEnabled = card.newFoldersCanSwitch
            if card.isOn, !card.newFoldersCanSwitch {
                newFolders.toolTip = String(
                    localized: "At least one add-on stays on in new folders")
            }
            let label = NSTextField(labelWithString: String(localized: "On in new folders"))
            views.append(NSStackView(views: [newFolders, label]))
        }
        let body = NSStackView(views: views)
        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = Self.bodySpacing
        body.edgeInsets = NSEdgeInsets(top: 0, left: Self.bodyIndent, bottom: 0, right: 0)
        return body
    }

    /// Try for 14 Days before a paid add-on was tried, and Buy… where it is sold without a
    /// licence (ADR 0071, ADR 0088); nil when neither applies.
    private static func offer(
        _ module: NameModuleDescription, licence: ModuleLicenceState?,
        startTrial: @escaping @MainActor () -> Void
    ) -> NSView? {
        guard let licence else { return nil }
        var buttons: [NSView] = []
        if licence == .notTried {
            buttons.append(
                ClosureButton(title: String(localized: "Try for 14 Days"), run: startTrial))
        }
        let isLicensed = if case .licensed = licence { true } else { false }
        if !isLicensed, module.purchaseURL != nil {
            buttons.append(
                ClosureButton(title: String(localized: "Buy…")) { LicenceText.buy(module) })
        }
        for case let button as NSButton in buttons { button.controlSize = .small }
        return buttons.isEmpty ? nil : NSStackView(views: buttons)
    }

    private static func fill(_ container: NSView?, with view: NSView, inset: CGFloat = 0) {
        guard let container else { return }
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset),
        ])
    }

    private static func caption(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabelColor
        return label
    }

    /// What the add-on reads of a file, in words (ADR 0061, ADR 0062).
    static func reads(_ module: NameModuleDescription) -> String {
        if module.neededContent.contains(.pageImages) {
            return String(localized: "Reads names and the pages of a file")
        }
        if !module.neededContent.isEmpty {
            return String(localized: "Reads names and the text of a file")
        }
        return String(localized: "Reads names only")
    }

    /// Which files the add-on is for, in words from its content types.
    static func files(_ module: NameModuleDescription) -> String {
        let types = module.contentTypes.compactMap { UTType($0) }
        if types.contains(where: { $0 == .item || $0 == .data }) {
            return String(localized: "all files")
        }
        return types.compactMap(\.localizedDescription).sorted().joined(separator: ", ")
    }
}
