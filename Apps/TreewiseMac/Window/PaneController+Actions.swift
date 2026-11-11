import AppKit
import TreewiseCore
import TreewiseUI

/// What the list and the icon view of a pane report back, turned into the
/// browser's actions.
extension PaneController {
    func actions(for tab: TabModel.ID) -> FileTableActions {
        let browser = browser
        let paneIndex = paneIndex
        let undoManager = SharedUndo.manager
        let clipboard = clipboard
        return FileTableActions(
            select: { browser.setSelection($0, in: tab) },
            open: { [weak self] item, command, option in
                self?.open(
                    item,
                    in: OpenPlacement.forOpening(
                        command: command, option: option,
                        preferred: browser.settings.doubleClickOpensIn))
            },
            sort: { browser.sort(by: $0) },
            focus: { browser.focusPane(paneIndex) },
            cut: clipboard.cut, copy: clipboard.copy, paste: clipboard.paste,
            canPaste: { clipboard.canPaste },
            rename: { item, name in
                Task { await browser.rename(item, to: name, undoManager: undoManager) }
            },
            renameStarted: {
                browser.renameRequest = nil
                defer { browser.renameSuggests = false }
                return browser.renameSuggests
            },
            revealed: { browser.revealRequest = nil },
            suggestName: { item, field in
                NameSuggestionList.show(
                    for: item, in: field, browser: browser, undoManager: undoManager)
            },
            contextMenu: { [contextMenu] in contextMenu.menu(for: $0) },
            drop: DropRouting.action(for: browser, undoManager: undoManager),
            previewURLs: { await browser.previewURLs(for: $0) },
            archiveDrag: { ArchiveEntryDrag(entry: $0, write: browser.entryCopier(for: $0)) })
    }

    private var contextMenu: FileContextMenu {
        let clipboard = clipboard
        return FileContextMenu(
            browser: browser, paneIndex: paneIndex, undoManager: SharedUndo.manager,
            cut: clipboard.cut, copy: clipboard.copy, paste: clipboard.paste,
            canPaste: { clipboard.canPaste })
    }

    private var clipboard: ClipboardCommands {
        ClipboardCommands(browser: browser, undoManager: SharedUndo.manager)
    }

    private func open(_ item: FileItem, in placement: OpenPlacement) {
        let browser = browser
        let paneIndex = paneIndex
        Task { await ItemOpening.open([item], from: paneIndex, in: placement, browser: browser) }
    }
}
