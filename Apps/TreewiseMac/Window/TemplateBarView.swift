import AppKit
import TreewiseCore
import TreewiseUI

/// The bar above the list of an empty folder that offers a template's folders (ADR 0094,
/// ADR 0097): `2027 is empty. Create the folders of 2026 here?`, Create Folders…, and a close
/// button whose menu hides it for this folder or for every folder in the one above.
@MainActor
final class TemplateBarView: NSStackView {
    private static let padding: CGFloat = 8
    private static let cornerRadius: CGFloat = 8

    private let browser: BrowserState
    private let label = NSTextField(labelWithString: "")
    private static let tint: CGFloat = 0.12
    private static let createTitle = String(localized: "Create Folders…")
    private lazy var create = ClosureButton(title: Self.createTitle) { [weak self] in
        self?.createFolders()
    }
    private let close = NSButton()
    /// The folder and emptiness last looked at, so a change of either looks again.
    private var lookedAt: (folder: FileItem.ID?, isEmpty: Bool)?
    private var offer: TemplateBarModel.Offer?

    init(browser: BrowserState) {
        self.browser = browser
        super.init(frame: .zero)
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        close.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: String(localized: "Close"))
        close.isBordered = false
        close.target = self
        close.action = #selector(showCloseMenu)
        create.controlSize = .small
        create.setAccessibilityIdentifier("templateBarCreate")
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        setViews([label, spacer, create, close], in: .leading)
        edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding * 2, bottom: Self.padding,
            right: Self.padding)
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(Self.tint).cgColor
        setAccessibilityIdentifier("templateBar")
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Looks again whether `folder` offers a template, when it or its emptiness changed.
    func follow(folder: FileItem?, isEmpty: Bool) {
        if let lookedAt, lookedAt.folder == folder?.id, lookedAt.isEmpty == isEmpty { return }
        lookedAt = (folder?.id, isEmpty)
        guard let folder, isEmpty else { return show(nil) }
        Task {
            let found = await FolderTemplatesService.bar(for: browser.fileSystem).offer(in: folder)
            guard lookedAt?.folder == folder.id else { return }
            show(found)
        }
    }

    private func show(_ found: TemplateBarModel.Offer?) {
        offer = found
        isHidden = found == nil
        guard let found else { return }
        let source = Self.sourceName(found.source)
        label.stringValue = String(
            localized: "\(found.folder.name) is empty. Create the folders of \(source) here?")
    }

    private static func sourceName(_ source: TemplateBarRule.Source) -> String {
        switch source {
        case .yearBefore(let id): id.rawValue.split(separator: "/").last.map(String.init) ?? ""
        case .template(let template): template.name
        }
    }

    private func createFolders() {
        guard let offer, let window else { return }
        Task {
            guard let tree = await tree(of: offer.source) else { return }
            var templateID: String?
            if case .template(let template) = offer.source { templateID = template.id }
            FolderTemplateSheet.present(
                .init(
                    title: String(
                        localized: "Create the Folders of \(Self.sourceName(offer.source))"),
                    tree: tree, templateID: templateID, place: .filling(offer.folder)),
                browser: browser, on: window, undoManager: SharedUndo.manager)
        }
    }

    /// The template's tree, or the folder a year before read as one.
    private func tree(of source: TemplateBarRule.Source) async -> FolderTree? {
        switch source {
        case .template(let template):
            return template.root
        case .yearBefore(let id):
            guard let addOn = FolderTemplatesService.addOn(licences: browser.licences),
                let folder = try? await browser.fileSystem.item(at: id),
                let tree = try? await browser.fileSystem.folderTree(of: folder)
            else { return nil }
            return try? await addOn.host.template(
                moduleID: addOn.moduleID, from: tree, yearAbove: YearFolders.year(of: id),
                licence: browser.licences?.context() ?? .none)
        }
    }

    @objc private func showCloseMenu() {
        guard let offer else { return }
        let menu = NSMenu()
        let here = String(localized: "Don’t Show for This Folder")
        menu.addItem(
            ClosureMenuItem(here, symbol: "eye.slash") { [weak self] in
                self?.hide { await $0.close(in: offer.folder.id) }
            })
        if let above = offer.folder.parentID {
            let name = above.rawValue.split(separator: "/").last.map(String.init) ?? ""
            let inAbove = String(localized: "Don’t Show in \(name)")
            menu.addItem(
                ClosureMenuItem(inAbove, symbol: "eye.slash") { [weak self] in
                    self?.hide { await $0.offerNothing(in: above) }
                })
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: close.bounds.height), in: close)
    }

    private func hide(_ change: @escaping @MainActor (TemplateBarModel) async -> Void) {
        show(nil)
        Task { await change(FolderTemplatesService.bar(for: browser.fileSystem)) }
    }
}
