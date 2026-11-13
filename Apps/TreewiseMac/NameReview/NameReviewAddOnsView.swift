import AppKit
import TreewiseCore
import TreewiseModuleInterface
import TreewiseUI

/// The add-ons and their patterns at the top of the overview, which close to one line.
@MainActor
final class NameReviewAddOnsView: NSObject {
    private static let visibleInSummary = 2
    private static let listMaximumHeight: CGFloat = 132
    private static let padding: CGFloat = 12
    private static let verticalPadding: CGFloat = 8
    private static let spacing: CGFloat = 6
    private static let blockSpacing: CGFloat = 5
    /// Whether the header was open when the user last left it, kept between reviews.
    private static let openKey = "nameReviewAddOnsOpen"

    private let model: NameReviewModel
    /// The app's licences, for Enter Licence Key… (ADR 0071).
    private let licences: LicenceKeeper?
    private let stack = NSStackView()
    private lazy var toggle = ClosureButton(title: "") { [weak self] in self?.toggleOpen() }
    private let reading = NSProgressIndicator()
    private let readingText = NSTextField(labelWithString: "")
    private let blocks = NSStackView()
    private lazy var list = scrolling(blocks)
    private var shownBlocks: [String: AddOnBlock] = [:]
    /// Whether the user opened or closed the header in this review, and which.
    private var wasToggled = false
    private var isOpenNow = false
    /// The add-on whose pattern is being edited.
    private var editing: String?

    init(model: NameReviewModel, licences: LicenceKeeper?) {
        self.model = model
        self.licences = licences
        super.init()
    }

    private var isOpen: Bool {
        wasToggled ? isOpenNow : (model.isFirstReview || Self.storedOpen)
    }

    private static var storedOpen: Bool {
        UserDefaults.standard.object(forKey: openKey) as? Bool ?? true
    }

    func makeView() -> NSView {
        toggle.isBordered = false
        toggle.imagePosition = .imageLeading
        toggle.font = .preferredFont(forTextStyle: .callout)
        reading.style = .spinning
        reading.controlSize = .small
        readingText.font = .preferredFont(forTextStyle: .caption1)
        readingText.textColor = .secondaryLabelColor
        let top = NSStackView()
        top.setViews([toggle], in: .leading)
        top.setViews([reading, readingText], in: .trailing)
        blocks.orientation = .vertical
        blocks.alignment = .leading
        blocks.spacing = Self.blockSpacing
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(
            top: Self.verticalPadding, left: Self.padding, bottom: Self.verticalPadding,
            right: Self.padding)
        stack.setViews([top, list], in: .leading)
        for view in [top, list] {
            view.widthAnchor.constraint(
                equalTo: stack.widthAnchor, constant: -Self.padding * 2
            ).isActive = true
        }
        Observing.follow(self) { $0.update() }
        return stack
    }

    private func scrolling(_ content: NSView) -> NSScrollView {
        let document = FlippedView()
        content.translatesAutoresizingMaskIntoConstraints = false
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(content)
        let scroll = NSScrollView()
        scroll.documentView = document
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        let height = scroll.heightAnchor.constraint(equalTo: document.heightAnchor)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            content.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            content.topAnchor.constraint(equalTo: document.topAnchor),
            content.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            scroll.heightAnchor.constraint(lessThanOrEqualToConstant: Self.listMaximumHeight),
            height,
        ])
        return scroll
    }

    private func update() {
        let isOpen = isOpen
        let title = title(isOpen: isOpen)
        toggle.title = title
        toggle.setAccessibilityLabel(title)
        toggle.image = NSImage(
            systemSymbolName: isOpen ? "chevron.down" : "chevron.right",
            accessibilityDescription: nil)
        toggle.isEnabled = !(isOpen && mustStayOpen)
        let count = model.readingCount
        reading.isHidden = count == 0
        readingText.isHidden = count == 0
        if count > 0 {
            reading.startAnimation(nil)
            readingText.stringValue = String(localized: "Reading \(count) files…")
        } else {
            reading.stopAnimation(nil)
        }
        list.isHidden = !isOpen
        if isOpen { showBlocks() }
    }

    private func showBlocks() {
        var shown: [AddOnBlock] = []
        for module in model.modules {
            let block = shownBlocks[module.id] ?? makeBlock(for: module.id)
            shownBlocks[module.id] = block
            block.show(module, isEditing: editing == module.id)
            shown.append(block)
        }
        if blocks.arrangedSubviews != shown { blocks.setViews(shown, in: .leading) }
    }

    private func makeBlock(for id: String) -> AddOnBlock {
        AddOnBlock(
            moduleID: id, model: model,
            actions: AddOnBlockActions(
                edit: { [weak self] in self?.edit($0) },
                save: { [weak self] in self?.askNameToSave($0) },
                enterKey: { [weak self] in self?.enterKey() },
                startTrial: { [weak self] in self?.startTrial(of: $0) }))
    }

    private func edit(_ id: String?) {
        editing = id
        update()
    }

    private func toggleOpen() {
        let open = !isOpen
        wasToggled = true
        isOpenNow = open
        UserDefaults.standard.set(open, forKey: Self.openKey)
        if !open { editing = nil }
        update()
    }

    private var mustStayOpen: Bool {
        guard let editing else { return false }
        return model.modules.first { $0.id == editing }?.templateProblem != nil
    }

    private func title(isOpen: Bool) -> String {
        guard !isOpen else { return String(localized: "Add-ons and their patterns") }
        let on = model.modules.filter(\.isOn)
        var names = on.prefix(Self.visibleInSummary).map { module in
            module.origin == .user
                ? "\(NameReviewText.name(of: module)) •" : NameReviewText.name(of: module)
        }.joined(separator: ", ")
        if on.count > Self.visibleInSummary { names += " +\(on.count - Self.visibleInSummary)" }
        return String(localized: "Add-ons: \(names)")
    }

    // MARK: - Saving a pattern and entering a key

    /// Asks the name to save the add-on's pattern under (ADR 0068).
    private func askNameToSave(_ id: String) {
        guard let window = stack.window else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Save Pattern")
        alert.informativeText = String(
            localized: "The pattern is kept under this name, to pick in other folders.")
        let name = NSTextField(string: "")
        name.placeholderString = String(localized: "Name")
        name.setFrameSize(
            NSSize(width: SavePatternAlert.fieldWidth, height: name.fittingSize.height))
        alert.accessoryView = name
        alert.addButton(withTitle: String(localized: "Save"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.window.initialFirstResponder = name
        let model = model
        alert.beginSheetModal(for: window) { response in
            let text = name.stringValue.trimmingCharacters(in: .whitespaces)
            guard response == .alertFirstButtonReturn, !text.isEmpty else { return }
            _ = model.savePattern(of: id, as: name.stringValue)
        }
    }

    private func startTrial(of moduleID: String) {
        licences?.startTrial(of: moduleID)
        let model = model
        Task { await model.start() }
    }

    private func enterKey() {
        guard let window = stack.window else { return }
        let model = model
        LicenceKeyEntry.present(on: window, keeper: licences, host: NameReviewWindow.host) {
            Task { await model.start() }
        }
    }
}

/// The size of the field in which a pattern's name is asked.
private enum SavePatternAlert {
    static let fieldWidth: CGFloat = 240
}
