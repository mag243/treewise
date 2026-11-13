import AppKit
import TreewiseCore
import TreewiseModuleInterface
import TreewiseUI

/// The Add-ons tab of Settings (ADR 0070): every add-on the app has, with what it reads,
/// which files it is for and the fields it fills in; on or off for every folder, on in new
/// folders or not, and dragged into the order folders without their own take. A paid one
/// shows its licence, with Try for 14 Days before it was tried and Buy… where it is sold;
/// one Enter Licence Key… serves them all (ADR 0071, ADR 0088).
@MainActor
final class AddOnsSettingsTab: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private static let dragType = NSPasteboard.PasteboardType("me.m-domain.treewise.add-on")
    private static let spacing: CGFloat = 8
    private static let width: CGFloat = 520
    private static let listHeight: CGFloat = 380

    private let settings: BrowserSettings
    /// The app's licences.
    private let licences: LicenceKeeper
    private let table = NSTableView()
    private lazy var enterKey = SettingsForm.button("Enter Licence Key…") { [weak self] in
        guard let self, let window = view.window else { return }
        LicenceKeyEntry.present(
            on: window, keeper: licences, host: NameReviewWindow.host
        ) { [weak self] in self?.load() }
    }
    /// Whether an add-on that asks may read the same folder a year before (ADR 0090).
    private lazy var yearBefore = SettingsForm.checkbox(
        "Also read names in the same folder a year before"
    ) { [settings] in settings.addOns.readsYearBefore = $0 }
    private let yearBeforeNote = NSTextField(
        wrappingLabelWithString: String(
            localized:
                "For an add-on that learns from last year, as in Administration/2025/Tax beside Administration/2026/Tax. Only names are read."
        ))
    private var modules: [NameModuleDescription] = []
    private var states: [String: ModuleLicenceState] = [:]
    private var shown: [NameModuleDescription] = []

    init(settings: BrowserSettings, licences: LicenceKeeper) {
        self.settings = settings
        self.licences = licences
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private var catalog: [String] { modules.map(\.id) }
    /// The add-ons on that may work: one of them stays on.
    private var working: [String] {
        settings.addOns.available(catalog).filter { states[$0]?.mayWork ?? true }
    }

    private var ordered: [NameModuleDescription] {
        settings.addOns.ordered(catalog).compactMap { id in modules.first { $0.id == id } }
    }

    override func loadView() {
        let header = NSTextField(labelWithString: String(localized: "Add-ons"))
        header.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let note = NSTextField(
            wrappingLabelWithString: String(
                localized:
                    "An add-on that is off is offered in no folder. Drag to set the order for folders without their own."
            ))
        note.font = .preferredFont(forTextStyle: .caption1)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = Self.width
        enterKey.isHidden = true
        yearBeforeNote.font = .preferredFont(forTextStyle: .caption1)
        yearBeforeNote.textColor = .secondaryLabelColor
        yearBeforeNote.preferredMaxLayoutWidth = Self.width
        let stack = NSStackView(
            views: [header, list(), note, yearBefore, yearBeforeNote, enterKey])
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
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        self.view = view
        Observing.follow(self) { $0.update() }
        load()
    }

    private func list() -> NSView {
        table.addTableColumn(NSTableColumn(identifier: .init("add-on")))
        table.headerView = nil
        table.usesAutomaticRowHeights = true
        table.selectionHighlightStyle = .none
        table.style = .plain
        table.dataSource = self
        table.delegate = self
        table.registerForDraggedTypes([Self.dragType])
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        table.backgroundColor = .clear
        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalToConstant: Self.width),
            scroll.heightAnchor.constraint(equalToConstant: Self.listHeight),
        ])
        return scroll
    }

    private func update() {
        yearBefore.state = settings.addOns.readsYearBefore ? .on : .off
        yearBefore.isHidden = !modules.contains(where: \.readsYearBefore)
        yearBeforeNote.isHidden = yearBefore.isHidden
        shown = ordered
        table.reloadData()
    }

    /// The add-ons, with each paid one's licence. None that another replaces is shown while
    /// that one may work, and the choices made for it go to that one (ADR 0067); one without
    /// a licence replaces nothing (ADR 0071).
    private func load() {
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

    private func move(_ id: String, to index: Int) {
        settings.addOns.move(id, to: index, catalog: catalog)
    }

    // MARK: - NSTableViewDataSource and NSTableViewDelegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        shown.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let module = shown[row]
        let view = AddOnRow(
            settings: settings, module: module, catalog: catalog,
            defaultID: NameModuleDescription.defaultID(among: modules),
            licence: states[module.id], isLastWorking: working == [module.id]
        ) { [weak self] id in
            self?.licences.startTrial(of: id)
            self?.load()
        }
        view.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: String(localized: "Move Up")) { [weak self] in
                self?.move(module.id, to: row - 1)
                return true
            },
            NSAccessibilityCustomAction(name: String(localized: "Move Down")) { [weak self] in
                self?.move(module.id, to: row + 1)
                return true
            },
        ])
        return view
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int)
        -> (any NSPasteboardWriting)?
    {
        let item = NSPasteboardItem()
        item.setString(shown[row].id, forType: Self.dragType)
        return item
    }

    func tableView(
        _ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard info.draggingSource as? NSTableView === table else { return [] }
        tableView.setDropRow(row, dropOperation: .above)
        return .move
    }

    func tableView(
        _ tableView: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard
            let id = info.draggingPasteboard.pasteboardItems?.first?.string(
                forType: Self.dragType),
            let from = shown.firstIndex(where: { $0.id == id })
        else { return false }
        move(id, to: row > from ? row - 1 : row)
        return true
    }
}
