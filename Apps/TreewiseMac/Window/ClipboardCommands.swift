import Foundation
import TreewiseCore
import TreewiseUI

/// Cut, copy and paste for the active pane, shared by the list, the icon view,
/// the context menu and the toolbar (ADR 0036), so each of them also writes
/// the system pasteboard and pastes what another app put there.
@MainActor
struct ClipboardCommands {
    let browser: BrowserState
    let undoManager: UndoManager?

    /// Cuts the selection to Treewise's clipboard and to the general pasteboard.
    func cut() {
        browser.cutSelection()
        FilePasteboard.write(browser.clipboard?.items ?? [])
    }

    /// Copies the selection to Treewise's clipboard and to the general pasteboard.
    func copy() {
        browser.copySelection()
        FilePasteboard.write(browser.clipboard?.items ?? [])
    }

    /// Whether Paste has anything: Treewise's clipboard or files on the pasteboard.
    var canPaste: Bool {
        browser.canAddItems && (browser.clipboard != nil || FilePasteboard.hasFileURLs)
    }

    /// Pastes Treewise's own clipboard, or files another app put on the
    /// pasteboard since, which are copied.
    func paste() {
        let browser = browser
        let undoManager = undoManager
        Task {
            if browser.clipboard != nil && !FilePasteboard.changedElsewhere {
                await browser.paste(resolver: AlertConflictResolver(), undoManager: undoManager)
                return
            }
            var items: [FileItem] = []
            for url in FilePasteboard.fileURLs() {
                if let item = try? await browser.item(at: FileItem.ID(url.standardizedFileURL.path))
                {
                    items.append(item)
                }
            }
            await browser.pasteItems(
                items, resolver: AlertConflictResolver(), undoManager: undoManager)
        }
    }
}
