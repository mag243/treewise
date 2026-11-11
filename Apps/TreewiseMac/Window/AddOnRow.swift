import AppKit
import TreewiseCore
import TreewiseModuleInterface
import TreewiseUI
import UniformTypeIdentifiers

/// One add-on in Settings' Add-ons tab: on or off with what it reads, which files it is
/// for and its fields, its licence for a paid one, and whether it is on in new folders.
@MainActor
final class AddOnRow: NSStackView {
    private static let indent: CGFloat = 20
    private static let lineSpacing: CGFloat = 3
    private static let rowPadding: CGFloat = 6
    private static let dimmed: CGFloat = 0.6

    /// Builds the row. `defaultID` is the add-on that plays the default module's part (ADR
    /// 0067), `licence` the licence of a paid one (ADR 0071), and `isLastWorking` whether it
    /// is the last add-on on that may work, which stays on.
    init(
        settings: BrowserSettings, module: NameModuleDescription, catalog: [String],
        defaultID: String, licence: ModuleLicenceState?, isLastWorking: Bool
    ) {
        super.init(frame: .zero)
        // Without a licence it is off and cannot be turned on; what was chosen is kept.
        let isLocked = licence == .unlicensed
        let isOn = settings.addOns.isOn(module.id) && !isLocked
        let isLast = isOn && isLastWorking
        orientation = .vertical
        alignment = .leading
        spacing = Self.lineSpacing
        edgeInsets = NSEdgeInsets(
            top: Self.rowPadding, left: 0, bottom: Self.rowPadding, right: 0)
        let toggle = ClosureCheckbox(title: NameReviewText.name(of: module)) {
            settings.addOns.setOn(module.id, on: $0, catalog: catalog)
        }
        toggle.state = isOn ? .on : .off
        toggle.isEnabled = !(isLast || isLocked)
        if isLast { toggle.toolTip = String(localized: "At least one add-on stays on") }
        let price = Self.caption(
            module.isFree ? String(localized: "Free") : String(localized: "Paid"))
        let top = NSStackView()
        top.setViews([toggle], in: .leading)
        top.setViews([price], in: .trailing)
        addArrangedSubview(top)
        let fields = module.fields.map { "{\($0.name)}" }.joined(separator: " ")
        for line in [
            Self.reads(module), String(localized: "For \(Self.files(module))"),
            String(localized: "Fields: \(fields)"),
        ] {
            addIndented(Self.caption(line))
        }
        if let licence { addIndented(licenceLine(licence, module: module, isLocked: isLocked)) }
        let newFolders = ClosureCheckbox(title: String(localized: "On in new folders")) {
            settings.addOns.setOnInNewFolders(
                module.id, on: $0, catalog: catalog, defaultID: defaultID)
        }
        newFolders.font = .preferredFont(forTextStyle: .caption1)
        newFolders.state =
            settings.addOns.isOnInNewFolders(module.id, defaultID: defaultID) ? .on : .off
        newFolders.isEnabled = isOn
        addIndented(newFolders)
        alphaValue = isOn ? 1 : Self.dimmed
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func addIndented(_ view: NSView) {
        let line = NSStackView(views: [view])
        line.edgeInsets = NSEdgeInsets(top: 0, left: Self.indent, bottom: 0, right: 0)
        addArrangedSubview(line)
    }

    private func licenceLine(
        _ licence: ModuleLicenceState, module: NameModuleDescription, isLocked: Bool
    ) -> NSView {
        let color: NSColor = isLocked ? .systemOrange : .secondaryLabelColor
        let icon = NSImageView(
            image: NSImage(
                systemSymbolName: isLocked ? "lock.fill" : "key.fill", accessibilityDescription: nil
            )
                ?? NSImage())
        icon.contentTintColor = color
        let text = Self.caption(LicenceText.state(licence))
        text.textColor = color
        var views: [NSView] = [icon, text]
        if !Self.isLicensed(licence), module.purchaseURL != nil {
            let link = ClosureButton(title: String(localized: "Buy…")) { LicenceText.buy(module) }
            link.isBordered = false
            link.contentTintColor = .linkColor
            link.font = .preferredFont(forTextStyle: .caption1)
            views.append(link)
        }
        return NSStackView(views: views)
    }

    private static func caption(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func isLicensed(_ state: ModuleLicenceState) -> Bool {
        if case .licensed = state { true } else { false }
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
