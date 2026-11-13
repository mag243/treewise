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
    private static let footSpacing: CGFloat = 6
    private static let groupPadding = NSSize(width: 12, height: 9)
    /// The width of the cards and the foot.
    static let width = SettingsWindow.paneSize.width - 2 * SettingsForm.margin

    let settings: BrowserSettings
    /// The app's licences.
    let licences: LicenceKeeper
    let table = NSTableView()
    private let scroll = NSScrollView()
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
    var modules: [NameModuleDescription] = []
    var states: [String: ModuleLicenceState] = [:]
    var shown: [NameModuleDescription] = []
    /// The add-on whose card is open; the first when none was chosen.
    var selectedID: String?

    init(settings: BrowserSettings, licences: LicenceKeeper) {
        self.settings = settings
        self.licences = licences
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    var catalog: [String] { modules.map(\.id) }
    /// The add-ons on that may work: one of them stays on.
    var working: [String] {
        settings.addOns.available(catalog).filter { states[$0]?.mayWork ?? true }
    }

    private var ordered: [NameModuleDescription] {
        settings.addOns.ordered(catalog).compactMap { id in modules.first { $0.id == id } }
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
        table.usesAutomaticRowHeights = true
        table.selectionHighlightStyle = .none
        table.allowsEmptySelection = false
        table.style = .plain
        table.intercellSpacing = NSSize(width: 0, height: Self.cardSpacing)
        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.registerForDraggedTypes([Self.dragType])
        table.setAccessibilityLabel(String(localized: "Add-ons"))
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
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
        let readsYearBefore = modules.contains(where: \.readsYearBefore)
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
    /// a licence replaces nothing (ADR 0071).
    func load() {
        let host = NameReviewWindow.host
        let context = licences.context()
        let settings = settings
        Task { [weak self] in
            let all = (try? await host.availableModules()) ?? []
            var found: [String: ModuleLicenceState] = [:]
            for module in all where !module.isFree {
                found[module.id] = try? await host.licenceState(
                    moduleID: module.id, licence: context)
            }
            let mayWork = { (module: NameModuleDescription) in found[module.id]?.mayWork ?? true }
            let offered = NameModuleDescription.offered(all.filter(mayWork))
            for module in all where !mayWork(module) {
                for replaced in module.replaces {
                    settings.addOns.handOver(from: module.id, to: replaced)
                }
            }
            for module in offered {
                for replaced in module.replaces {
                    settings.addOns.handOver(from: replaced, to: module.id)
                }
            }
            guard let self else { return }
            states = found
            modules = offered + all.filter { !mayWork($0) }
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
