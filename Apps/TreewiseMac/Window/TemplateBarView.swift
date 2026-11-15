import AppKit
import TreewiseCore
import TreewiseUI

/// The bar above a folder's list that offers folders to make (ADR 0094, ADR 0097, ADR 0102).
/// In an empty folder, a template's folders: `2027 is empty. Create the folders of 2026 here?`
/// with Create Folders…. In a year's folder that holds items, the folders of the year before
/// it lacks: `2027 lacks 1 folder of 2026.` with Create Folders… and, for the one `{year}`
/// template lacking them, Add to Template. Its close button's menu hides it.
@MainActor
final class TemplateBarView: NSStackView {
    private static let padding: CGFloat = 8
    private static let cornerRadius: CGFloat = 8

    /// What the bar offers.
    enum Shown {
        /// A template's folders, in an empty folder.
        case empty(TemplateBarModel.Offer)
        /// The folders of the year before that a year's folder lacks.
        case missing(TemplateBarModel.MissingOffer)
    }

    /// What the bar last looked at: the folder, whether it is empty, and for a year's own
    /// folder, whose missing folders change with them, the names of what it holds.
    private struct LookedAt: Equatable {
        let folder: FileItem.ID?
        let isEmpty: Bool
        let names: Set<String>
    }

    let browser: BrowserState
    private let label = NSTextField(labelWithString: "")
    private static let tint: CGFloat = 0.12
    private static let createTitle = String(localized: "Create Folders…")
    private static let addTitle = String(localized: "Add to Template")
    private lazy var create = ClosureButton(title: Self.createTitle) { [weak self] in
        self?.createFolders()
    }
    private lazy var addToTemplate = ClosureButton(title: Self.addTitle) { [weak self] in
        self?.addMissingToTemplate()
    }
    private let close = NSButton()
    private var lookedAt: LookedAt?
    private var followed: (folder: FileItem?, items: [FileItem]) = (nil, [])
    private(set) var shown: Shown?

    init(browser: BrowserState) {
        self.browser = browser
        super.init(frame: .zero)
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setAccessibilityIdentifier("templateBarText")
        close.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: String(localized: "Close"))
        close.isBordered = false
        close.target = self
        close.action = #selector(showCloseMenu)
        close.setAccessibilityIdentifier("templateBarClose")
        create.controlSize = .small
        create.setAccessibilityIdentifier("templateBarCreate")
        addToTemplate.controlSize = .small
        addToTemplate.setAccessibilityIdentifier("templateBarAddToTemplate")
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        setViews([label, spacer, addToTemplate, create, close], in: .leading)
        edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding * 2, bottom: Self.padding,
            right: Self.padding)
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(Self.tint).cgColor
        setAccessibilityIdentifier("templateBar")
        isHidden = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(foldersMade), name: FolderTemplateSheet.foldersMade,
            object: nil)
    }

    /// Folders made anywhere, at any depth, may be those the bar offers.
    @objc private func foldersMade() {
        lookAgain()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Looks again what `folder` is offered, when it or what it holds changed.
    func follow(folder: FileItem?, items: [FileItem]) {
        let isYears = folder.flatMap { YearFolders.ownYear(of: $0.id) } != nil
        let now = LookedAt(
            folder: folder?.id, isEmpty: items.isEmpty,
            names: isYears ? Set(items.map(\.name)) : [])
        guard now != lookedAt else { return }
        lookedAt = now
        followed = (folder, items)
        guard let folder else { return show(nil) }
        let bar = FolderTemplatesService.bar(for: browser)
        Task {
            var found: Shown?
            if items.isEmpty {
                found = await bar.offer(in: folder).map(Shown.empty)
            } else {
                found = await bar.missing(in: folder).map(Shown.missing)
            }
            guard lookedAt == now else { return }
            show(found)
        }
    }

    /// Looks again at the folder last followed, after the template changed.
    func lookAgain() {
        lookedAt = nil
        follow(folder: followed.folder, items: followed.items)
    }

    func show(_ found: Shown?) {
        shown = found
        isHidden = found == nil
        addToTemplate.isHidden = true
        switch found {
        case .empty(let offer):
            let source = Self.sourceName(offer.source)
            label.stringValue = String(
                localized: "\(offer.folder.name) is empty. Create the folders of \(source) here?")
        case .missing(let offer):
            label.stringValue = String(
                localized:
                    "\(offer.folder.name) lacks \(offer.missing.paths.count) folders of \(Self.name(of: offer.yearBefore))."
            )
            addToTemplate.isHidden = offer.template == nil
        case nil:
            break
        }
    }

    static func name(of folder: FileItem.ID) -> String {
        folder.rawValue.split(separator: "/").last.map(String.init) ?? ""
    }

    private static func sourceName(_ source: TemplateBarRule.Source) -> String {
        switch source {
        case .yearBefore(let id): name(of: id)
        case .template(let template): template.name
        }
    }

    private func createFolders() {
        guard let shown, let window else { return }
        switch shown {
        case .empty(let offer):
            Task { await createFolders(of: offer, on: window) }
        case .missing(let offer):
            FolderTemplateMenu.presentMissing(
                offer, browser: browser, on: window, undoManager: SharedUndo.manager)
        }
    }

    private func createFolders(of offer: TemplateBarModel.Offer, on window: NSWindow) async {
        guard let tree = await tree(of: offer.source) else { return }
        var templateID: String?
        if case .template(let template) = offer.source { templateID = template.id }
        FolderTemplateSheet.present(
            .init(
                title: String(localized: "Create the Folders of \(Self.sourceName(offer.source))"),
                tree: tree, templateID: templateID, place: .filling(offer.folder)),
            browser: browser, on: window, undoManager: SharedUndo.manager)
    }

    /// The template's tree, or the folder a year before read as one.
    private func tree(of source: TemplateBarRule.Source) async -> FolderTree? {
        switch source {
        case .template(let template):
            template.root
        case .yearBefore(let id):
            await FolderTemplatesService.recognized(
                id, in: browser.fileSystem, licences: browser.licences)
        }
    }

    private func addMissingToTemplate() {
        guard case .missing(let offer) = shown, let template = offer.template else { return }
        Task {
            await FolderTemplatesService.addMissing(
                of: offer, to: template, undoManager: SharedUndo.manager)
            lookAgain()
        }
    }

    @objc private func showCloseMenu() {
        guard let shown else { return }
        let menu = NSMenu()
        for item in closeItems(for: shown) { menu.addItem(item) }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: close.bounds.height), in: close)
    }

    func hide(_ change: @escaping @MainActor (TemplateBarModel) async -> Void) {
        show(nil)
        let bar = FolderTemplatesService.bar(for: browser)
        Task { await change(bar) }
    }
}
