import AppKit
import TreewiseCore
import TreewiseModuleInterface
import TreewiseUI

/// The Add-ons tab of Settings (ADR 0070, ADR 0092): every add-on the app has as a card,
/// the selected one open, in a list that fills the tab and is dragged to set the order;
/// below it, in place, the settings for all add-ons and Enter Licence Key…, which serves
/// every paid one (ADR 0071, ADR 0088).
@MainActor
final class AddOnsSettingsTab: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    static let dragType = NSPasteboard.PasteboardType("me.m-domain.treewise.add-on")
    private static let spacing: CGFloat = 8
    private static let cardSpacing: CGFloat = 8
    private static let groupPadding = NSSize(width: 12, height: 9)
    /// The width of the list and the foot, as every list in Settings.
    static let width = SettingsList.width
    /// The room between the list's border and its cards.
    static let listInset: CGFloat = 8
    /// The room between a heading in the list and the card under it.
    static let headingSpacing: CGFloat = 4

    /// The width of a card: the width the list shows, less the same room on either side as
    /// above and below; a scroller takes its room only while there is something to scroll.
    var cardWidth: CGFloat {
        let shown = scroll.contentSize.width > 0 ? scroll.contentSize.width : Self.width
        return shown - 2 * Self.listInset
    }

    let settings: BrowserSettings
    /// The app's licences.
    let licences: LicenceKeeper
    let table = AddOnCardTable()
    private let scroll = NSScrollView()
    private var contextMenu: SettingsListMenu?
    private lazy var enterKey = SettingsForm.button("Enter Licence Key…") { [weak self] in
        guard let self, let window = view.window else { return }
        LicenceKeyEntry.present(
            on: window, keeper: licences, host: NameReviewWindow.host
        ) { [weak self] in self?.load() }
    }
    /// Whether an add-on that asks may read the same folder a year before (ADR 0090).
    private lazy var yearBefore = ClosureSwitch(
        label: String(localized: "Also read names in the same folder a year before")
    ) { [settings] in settings.addOns.readsYearBefore = $0 }
    private var reading: [NSView] = []
    var modules: [AddOnDescription] = []
    var states: [String: ModuleLicenceState] = [:]
    var shown: [AddOnDescription] = []
    /// The add-on whose card is open; the first when none was chosen.
    var selectedID: String?

    init(settings: BrowserSettings, licences: LicenceKeeper) {
        self.settings = settings
        self.licences = licences
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// The add-ons that propose names, whose order and on or off Settings keeps (ADR 0070).
    var catalog: [String] { modules.filter { $0.proposesNames }.map(\.id) }
    /// The add-ons on that may work: one of them stays on.
    var working: [String] {
        settings.addOns.available(catalog).filter { states[$0]?.mayWork ?? true }
    }

    /// The add-ons that propose names in their order, then those that make folder structures
    /// (ADR 0091).
    private var ordered: [AddOnDescription] {
        settings.addOns.ordered(catalog).compactMap { id in modules.first { $0.id == id } }
            + modules.filter { $0.makesFolderStructures }
    }

    override func loadView() {
        let header = NSTextField(labelWithString: String(localized: "Add-ons"))
        header.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        enterKey.isHidden = true
        let list = list()
        let stack = NSStackView(views: [header, list] + foot())
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        let size = SettingsWindow.paneSize
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: size.width),
            view.heightAnchor.constraint(equalToConstant: size.height),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: SettingsForm.margin),
            stack.bottomAnchor.constraint(
                equalTo: view.bottomAnchor, constant: -SettingsForm.margin),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.widthAnchor.constraint(equalToConstant: Self.width),
        ])
        self.view = view
        Observing.follow(self) { $0.update() }
        load()
    }

    /// The cards, in a list that takes the height the foot leaves.
    private func list() -> NSView {
        table.addTableColumn(NSTableColumn(identifier: .init("add-on")))
        table.headerView = nil
        table.selectionHighlightStyle = .none
        table.allowsEmptySelection = false
        table.style = .plain
        table.intercellSpacing = NSSize(width: 0, height: Self.cardSpacing)
        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.registerForDraggedTypes([Self.dragType])
        table.setAccessibilityLabel(String(localized: "Add-ons"))
        table.canDrag = { [weak self] row, point in self?.cardGrips(row: row, at: point) ?? false }
        contextMenu = SettingsListMenu(for: table) { [weak self] row in
            self?.cardMenuItems(for: row) ?? []
        }
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        // In a border as the other lists of Settings, so it shows where the list ends.
        scroll.borderType = .bezelBorder
        scroll.automaticallyAdjustsContentInsets = false
        // Above and below the cards; beside them, each row keeps the room itself.
        scroll.contentInsets = NSEdgeInsets(
            top: Self.listInset, left: 0, bottom: Self.listInset, right: 0)
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        scroll.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        scroll.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        return scroll
    }

    /// Reading, with the year before, then the note and Enter Licence Key…, in place.
    private func foot() -> [NSView] {
        let heading = NSTextField(labelWithString: String(localized: "Reading"))
        heading.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        heading.textColor = .secondaryLabelColor
        reading = [heading, readingGroup()]
        return reading + [bottomRow()]
    }

    /// The year before as a switch, with its title and note, in a group (ADR 0090).
    private func readingGroup() -> NSView {
        let title = NSTextField(
            labelWithString: String(localized: "Also read names in the same folder a year before"))
        let note = Self.note(
            String(
                localized:
                    "For an add-on that learns from last year, as in Administration/2025/Tax beside Administration/2026/Tax. Only names are read."
            ),
            width: Self.width - 2 * Self.groupPadding.width - yearBefore.fittingSize.width
                - Self.spacing)
        let words = NSStackView(views: [title, note])
        words.orientation = .vertical
        words.alignment = .leading
        words.spacing = 2
        let row = NSStackView(views: [words, yearBefore])
        row.alignment = .centerY
        row.spacing = Self.spacing
        let group = AddOnCardStyle.group(
            fill: AddOnCardStyle.cardFill, border: .separatorColor,
            radius: AddOnCardStyle.cardRadius)
        group.contentViewMargins = Self.groupPadding
        group.contentView?.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        if let content = group.contentView {
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                row.topAnchor.constraint(equalTo: content.topAnchor),
                row.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        }
        group.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        return group
    }

    /// The note on turning off and dragging, beside Enter Licence Key….
    private func bottomRow() -> NSView {
        enterKey.setContentCompressionResistancePriority(.required, for: .horizontal)
        enterKey.setContentHuggingPriority(.required, for: .horizontal)
        let note = Self.note(
            String(
                localized:
                    "An add-on that is off is offered in no folder. Drag to set the order for folders without their own."
            ), width: Self.width - enterKey.fittingSize.width - Self.spacing)
        let bottom = NSStackView(views: [note, enterKey])
        bottom.alignment = .centerY
        bottom.spacing = Self.spacing
        bottom.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        return bottom
    }

    private static func note(_ text: String, width: CGFloat) -> NSTextField {
        let note = NSTextField(wrappingLabelWithString: text)
        note.font = .preferredFont(forTextStyle: .caption1)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = width
        note.setContentCompressionResistancePriority(.required, for: .vertical)
        return note
    }

    private func update() {
        yearBefore.state = settings.addOns.readsYearBefore ? .on : .off
        let readsYearBefore = modules.contains(where: \.names.readsYearBefore)
        for view in reading { view.isHidden = !readsYearBefore }
        shown = ordered
        // The selection is known before the cards are made, so the right one opens.
        let index = shown.firstIndex { $0.id == selectedID } ?? 0
        selectedID = index < shown.count ? shown[index].id : nil
        table.reloadData()
        if index < shown.count {
            table.selectRowIndexes([index], byExtendingSelection: false)
        }
    }

    /// The add-ons, with each paid one's licence. None that another replaces is shown while
    /// that one may work, and the choices made for it go to that one (ADR 0067); one without
    /// a licence replaces nothing (ADR 0071). A trial started or a key entered here reaches
    /// the template items and the Templates tab at once (ADR 0095, ADR 0102).
    func load() {
        let host = NameReviewWindow.host
        let context = licences.context()
        let settings = settings
        let licences = licences
        Task { [weak self] in
            await FolderTemplatesService.refresh(licences: licences)
            let all = (try? await host.availableModules()) ?? []
            var found: [String: ModuleLicenceState] = [:]
            for module in all where !module.isFree {
                found[module.id] = try? await host.licenceState(
                    moduleID: module.id, licence: context)
            }
            let mayWork = { (module: AddOnDescription) in found[module.id]?.mayWork ?? true }
            let offered = AddOnDescription.offered(forNames: all.filter(mayWork))
            for module in all where !mayWork(module) {
                for replaced in module.names.replaces {
                    settings.addOns.handOver(from: module.id, to: replaced)
                }
            }
            for module in offered {
                for replaced in module.names.replaces {
                    settings.addOns.handOver(from: replaced, to: module.id)
                }
            }
            guard let self else { return }
            states = found
            modules =
                offered + all.filter { $0.proposesNames && !mayWork($0) }
                + all.filter { $0.makesFolderStructures }
            enterKey.isHidden = found.isEmpty
            update()
        }
    }

    func move(_ id: String, to index: Int) {
        settings.addOns.move(id, to: index, catalog: catalog)
    }

    /// Scrolls the list so the selected card shows whole, or its top when it is taller
    /// than the list (ADR 0092).
    func revealSelection() {
        let row = table.selectedRow
        guard row >= 0 else { return }
        table.layoutSubtreeIfNeeded()
        let card = table.rect(ofRow: row)
        let clip = scroll.contentView
        let visible = clip.bounds
        guard
            let top = RevealScroll.top(
                card: Double(card.minY)..<Double(card.maxY), visibleTop: Double(visible.minY),
                visibleHeight: Double(visible.height), contentHeight: Double(table.frame.height))
        else { return }
        let origin = NSPoint(x: visible.minX, y: CGFloat(top))
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            clip.setBoundsOrigin(origin)
        } else {
            NSAnimationContext.runAnimationGroup { _ in clip.animator().setBoundsOrigin(origin) }
        }
        scroll.reflectScrolledClipView(clip)
    }
}
