import AppKit
import TreewiseCore
import TreewiseUI

/// The actions of the command bar (ADR 0036, ADR 0037), the prototype's with
/// Rename and Share added: one-click versions of the menu items for the
/// window's folder, each enabled only when its menu item would be. Each
/// button shows its icon, with its name as help tag and VoiceOver name.
@MainActor
final class CommandBarActions: NSStackView {
    private static let spacing: CGFloat = 8

    private let browser: BrowserState
    private var buttons: [Action: NSButton] = [:]
    /// Whether another app put files on the pasteboard; it does not say when,
    /// so this is checked when Treewise becomes active and the clipboard changes.
    private var pasteboardHasFiles = FilePasteboard.hasFileURLs

    init(browser: BrowserState) {
        self.browser = browser
        super.init(frame: .zero)
        spacing = Self.spacing
        for action in Action.allCases {
            let run: @MainActor () -> Void = { [weak self] in self?.run(action) }
            let button = ActionButton(title: action.title, symbol: action.symbol, run: run)
            buttons[action] = button
            addArrangedSubview(button)
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(becameActive),
            name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Enables the buttons as their menu items would be. Returns whether a
    /// button came or went, which changes the width of the bar.
    func update() -> Bool {
        // The clipboard changed, or may have: another app's files count too.
        if browser.clipboard == nil { pasteboardHasFiles = FilePasteboard.hasFileURLs }
        for action in Action.allCases { buttons[action]?.isEnabled = canRun(action) }
        guard let extract = buttons[.extract] else { return false }
        let showsExtract = browser.canExtractSelection
        defer { extract.isHidden = !showsExtract }
        return extract.isHidden == showsExtract
    }

    @objc private func becameActive() {
        pasteboardHasFiles = FilePasteboard.hasFileURLs
        buttons[.paste]?.isEnabled = canRun(.paste)
    }

    private func canRun(_ action: Action) -> Bool {
        switch action {
        case .cut: browser.canCutSelection
        case .copy: browser.canCopySelection
        case .paste: browser.canAddItems && (browser.clipboard != nil || pasteboardHasFiles)
        case .rename: browser.canRenameSelection
        case .extract: browser.canExtractSelection
        case .share: !browser.selectedItems.isEmpty
        case .trash: browser.canTrashSelection
        case .terminal: TerminalOpener.isAvailable && browser.terminalFolder != nil
        }
    }

    private func run(_ action: Action) {
        let browser = browser
        let undoManager = SharedUndo.manager
        let clipboard = ClipboardCommands(browser: browser, undoManager: undoManager)
        switch action {
        case .cut: clipboard.cut()
        case .copy: clipboard.copy()
        case .paste: clipboard.paste()
        case .rename: browser.renameRequest = browser.selectedItems.first?.id
        case .extract: ArchiveCommands(browser: browser, undoManager: undoManager).extract()
        case .share: share()
        case .trash: Task { await browser.moveSelectionToTrash(undoManager: undoManager) }
        case .terminal: TerminalOpener.open(browser.terminalFolder, settings: browser.settings)
        }
    }

    private func share() {
        guard let button = buttons[.share] else { return }
        let urls = browser.selectedItems.compactMap(\.id.diskURL)
        NSSharingServicePicker(items: urls).show(
            relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

/// The actions of the command bar, in their order.
private enum Action: CaseIterable {
    case cut, copy, paste, rename, extract, share, trash, terminal

    var title: String {
        switch self {
        case .cut: String(localized: "Cut")
        case .copy: String(localized: "Copy")
        case .paste: String(localized: "Paste")
        case .rename: String(localized: "Rename")
        case .extract: String(localized: "Extract All…")
        case .share: String(localized: "Share")
        case .trash: String(localized: "Move to Trash")
        case .terminal: String(localized: "Open in Terminal")
        }
    }

    var symbol: String {
        switch self {
        case .cut: "scissors"
        case .copy: "doc.on.doc"
        case .paste: "doc.on.clipboard"
        case .rename: "pencil"
        case .extract: "arrow.up.bin"
        case .share: "square.and.arrow.up"
        case .trash: "trash"
        case .terminal: "terminal"
        }
    }
}

/// A borderless button with an icon that runs a closure, named by its title
/// for VoiceOver and in its help tag.
@MainActor
final class ActionButton: NSButton {
    private let run: @MainActor () -> Void

    init(title: String, symbol: String, run: @escaping @MainActor () -> Void) {
        self.run = run
        super.init(frame: .zero)
        self.title = title
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        imagePosition = .imageOnly
        isBordered = false
        toolTip = title
        setAccessibilityLabel(title)
        target = self
        action = #selector(runAction)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func runAction() {
        run()
    }
}
