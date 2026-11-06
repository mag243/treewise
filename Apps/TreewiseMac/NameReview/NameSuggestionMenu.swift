import AppKit
import TreewiseCore
import TreewiseUI

/// The menu of proposals under the name of a file being renamed, asked for with ⌥Esc, F5
/// or Rename with Suggestions (ADR 0066). It asks the folder's add-ons about this file
/// alone, as a review of one file, and choosing an option only puts it in the field: the
/// user's own Return renames.
@MainActor
final class NameSuggestionMenu: NSObject {
    /// The space between the field and the menu below it.
    private static let gapBelowField: CGFloat = 2
    /// The menu being shown, kept while it is open.
    private static var shown: NameSuggestionMenu?

    private let menu = NSMenu()
    private let item: FileItem
    private weak var field: NSTextField?
    private let browser: BrowserState
    private weak var undoManager: UndoManager?
    private var model: NameReviewModel?

    private init(
        item: FileItem, field: NSTextField, browser: BrowserState, undoManager: UndoManager?
    ) {
        self.item = item
        self.field = field
        self.browser = browser
        self.undoManager = undoManager
    }

    /// Shows the proposals for `item` under `field`; a folder or a file that cannot be
    /// renamed gets a beep.
    static func show(
        for item: FileItem, in field: NSTextField, browser: BrowserState, undoManager: UndoManager?
    ) {
        guard browser.canSuggestName(for: item) else {
            NSSound.beep()
            return
        }
        let menu = NameSuggestionMenu(
            item: item, field: field, browser: browser, undoManager: undoManager)
        shown = menu
        menu.present(under: field)
    }

    private func present(under field: NSTextField) {
        menu.autoenablesItems = false
        show(note: String(localized: "Reading the file…"))
        // The menu tracks on the main run loop, which still runs this when it is done.
        Task { await ask() }
        let below = field.isFlipped ? field.bounds.maxY + Self.gapBelowField : -Self.gapBelowField
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: below), in: field)
        model?.stop()
        Self.shown = nil
    }

    private func ask() async {
        guard
            let model = await browser.makeNameProposals(
                for: item, host: NameReviewWindow.host, store: NameReviewWindow.store)
        else {
            show(note: String(localized: "No proposal."))
            return
        }
        self.model = model
        await model.start()
        await model.waitUntilRead()
        showOptions(of: model)
    }

    private func showOptions(of model: NameReviewModel) {
        let options = model.options(of: item.id)
        guard !options.isEmpty else {
            show(note: emptyNote(for: model.session?.entry(item.id)))
            return
        }
        menu.removeAllItems()
        for option in options { menu.addItem(menuItem(for: option)) }
        addOverviewItem()
    }

    private func emptyNote(for entry: NameProposalSession.Entry?) -> String {
        if entry?.isOutOfScope == true { return String(localized: "Not for these add-ons.") }
        if entry?.restsFitting == true { return String(localized: "This name already fits.") }
        return String(localized: "No proposal.")
    }

    private func show(note: String) {
        menu.removeAllItems()
        let line = NSMenuItem(title: note, action: nil, keyEquivalent: "")
        line.isEnabled = false
        menu.addItem(line)
        addOverviewItem()
    }

    private func addOverviewItem() {
        menu.addItem(.separator())
        let overview = NSMenuItem(
            title: String(localized: "Suggest Names…"), action: #selector(openOverview),
            keyEquivalent: "")
        overview.target = self
        menu.addItem(overview)
    }

    /// An option with its fields in their colours, and a warning for personal data or a gap.
    private func menuItem(for option: NameOption) -> NSMenuItem {
        let entry = NSMenuItem(title: option.name, action: #selector(choose(_:)), keyEquivalent: "")
        entry.target = self
        entry.representedObject = option.name
        let title = NSMutableAttributedString(
            string: option.name, attributes: [.font: NSFont.menuFont(ofSize: 0)])
        for mark in option.marks {
            title.addAttribute(
                .backgroundColor, value: FieldColors.color(mark.colorIndex),
                range: NSRange(mark.range, in: option.name))
        }
        entry.attributedTitle = title
        let warnings =
            option.personalData.map(NameReviewText.text(for:))
            + (option.hasGap ? [String(localized: "Fill in the gap to approve")] : [])
        if !warnings.isEmpty {
            entry.image = NSImage(
                systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            entry.toolTip = warnings.joined(separator: "\n")
        }
        return entry
    }

    /// Puts the option in the field, with a gap selected to fill in, or the cursor before
    /// the extension.
    @objc private func choose(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String, let field else { return }
        field.stringValue = name
        let text = name as NSString
        let gap = text.range(of: NameTemplate.gap)
        field.currentEditor()?.selectedRange =
            gap.location != NSNotFound
            ? gap : NSRange(location: (ProposedName.stem(of: name) as NSString).length, length: 0)
    }

    /// Leaves the rename and opens the overview for this file, where its pattern can change.
    @objc private func openOverview() {
        field?.currentEditor()?.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        NameReviewWindow.show(for: browser, undoManager: undoManager)
    }
}
