import AppKit
import TreewiseCore
import TreewiseUI

/// The proposals under the name of a file being renamed, asked for with ⌥Esc, F5 or
/// Rename with Suggestions (ADR 0066). It asks the folder's add-ons about this file alone,
/// as a review of one file, and choosing an option only puts it in the field: the user's
/// own Return renames. While it is open, ↑ and ↓ move in it, Return takes the highlighted
/// option and Escape closes it; it closes by itself when the rename ends.
@MainActor
final class NameSuggestionList {
    /// The key codes the list takes from the name while it is open.
    private enum Key {
        static let returnKey: UInt16 = 36
        static let enter: UInt16 = 76
        static let escape: UInt16 = 53
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }

    /// The list being shown, kept while it is open.
    private static var shown: NameSuggestionList?

    private let panel = NameSuggestionPanel()
    private let item: FileItem
    private weak var field: NSTextField?
    private let browser: BrowserState
    private weak var undoManager: UndoManager?
    private var model: NameReviewModel?
    private var asking: Task<Void, Never>?
    private var keyMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    /// Whether the list was closed, after which the add-ons' answer is not shown.
    private var isClosed = false

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
        shown?.close()
        let list = NameSuggestionList(
            item: item, field: field, browser: browser, undoManager: undoManager)
        shown = list
        list.open(under: field)
    }

    private func open(under field: NSTextField) {
        panel.onChoose = { [weak self] in self?.choose($0) }
        show(note: String(localized: "Reading the file…"))
        watch(field)
        asking = Task { await ask() }
    }

    private func close() {
        isClosed = true
        asking?.cancel()
        model?.stop()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        panel.close()
        if Self.shown === self { Self.shown = nil }
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
        guard !Task.isCancelled else { return }
        showOptions(of: model)
    }

    private func showOptions(of model: NameReviewModel) {
        let options = model.options(of: item.id)
        guard !options.isEmpty else {
            show(note: emptyNote(for: model.session?.entry(item.id)))
            return
        }
        show(options.map(NameSuggestionPanel.Row.option) + [.separator, .overview])
    }

    private func emptyNote(for entry: NameProposalSession.Entry?) -> String {
        if entry?.isOutOfScope == true { return String(localized: "Not for these add-ons.") }
        if entry?.restsFitting == true { return String(localized: "This name already fits.") }
        return String(localized: "No proposal.")
    }

    private func show(note: String) {
        show([.note(note), .separator, .overview])
    }

    private func show(_ rows: [NameSuggestionPanel.Row]) {
        guard !isClosed, let field else { return }
        panel.show(rows, under: field)
    }

    /// Takes the keys of the list from the name, and closes the list when the rename ends,
    /// the user types or the window goes to the background.
    private func watch(_ field: NSTextField) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) == true } ? nil : event
        }
        let center = NotificationCenter.default
        let close: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        observers = [
            center.addObserver(
                forName: NSControl.textDidEndEditingNotification, object: field, queue: .main,
                using: close),
            center.addObserver(
                forName: NSWindow.didResignKeyNotification, object: field.window, queue: .main,
                using: close),
            // Typing makes the name the user's own, so Return renames it as typed.
            center.addObserver(
                forName: NSControl.textDidChangeNotification, object: field, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.panel.highlight(nil) }
            },
        ]
    }

    /// Whether the list took this key press.
    private func handle(_ event: NSEvent) -> Bool {
        guard let field, field.currentEditor() != nil, event.window === field.window,
            event.modifierFlags.isDisjoint(with: [.command, .option, .control])
        else { return false }
        switch event.keyCode {
        case Key.down:
            panel.moveHighlight(by: 1)
            return true
        case Key.up:
            panel.moveHighlight(by: -1)
            return true
        case Key.returnKey, Key.enter:
            if let highlighted = panel.highlighted {
                choose(highlighted)
                return true
            }
            close()
            return false
        case Key.escape:
            close()
            return true
        default:
            return false
        }
    }

    private func choose(_ index: Int) {
        guard panel.rows.indices.contains(index) else { return }
        switch panel.rows[index] {
        case .option(let option):
            close()
            put(option.name)
        case .overview:
            close()
            openOverview()
        case .note, .separator:
            break
        }
    }

    /// Puts the name in the field, with a gap selected to fill in, or the cursor before
    /// the extension.
    private func put(_ name: String) {
        guard let field else { return }
        field.stringValue = name
        let gap = (name as NSString).range(of: NameTemplate.gap)
        field.currentEditor()?.selectedRange =
            gap.location != NSNotFound
            ? gap : NSRange(location: (ProposedName.stem(of: name) as NSString).length, length: 0)
    }

    /// Leaves the rename and opens the overview for this file, where its pattern can change.
    private func openOverview() {
        field?.currentEditor()?.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        NameReviewWindow.show(for: browser, undoManager: undoManager)
    }
}
