import AppKit
import SwiftUI
import TreewiseCore
import TreewiseUI

/// The actions of the command bar (ADR 0036, ADR 0037), the prototype's with
/// Rename and Share added: one-click versions of the menu items for the
/// window's folder, each enabled only when its menu item would be.
struct CommandBarActions: View {
    private static let spacing: CGFloat = 4

    let browser: BrowserState
    let undoManager: UndoManager?
    /// Whether another app put files on the pasteboard; it does not say when,
    /// so this is checked when Treewise becomes active.
    @State private var pasteboardHasFiles = FilePasteboard.hasFileURLs

    var body: some View {
        let selection = browser.selectedItems
        let clipboard = ClipboardCommands(browser: browser, undoManager: undoManager)
        HStack(spacing: 0) {
            action("Cut", "scissors", disabled: !browser.canCutOrCopySelection, run: clipboard.cut)
            action(
                "Copy", "doc.on.doc", disabled: !browser.canCutOrCopySelection, run: clipboard.copy)
            action(
                "Paste", "doc.on.clipboard",
                disabled: browser.clipboard == nil && !pasteboardHasFiles, run: clipboard.paste)
            action("Rename", "pencil", disabled: !browser.canRenameSelection) {
                browser.renameRequest = selection.first?.id
            }
            if browser.canExtractSelection {
                action("Extract All…", "arrow.up.bin") {
                    ArchiveCommands(browser: browser, undoManager: undoManager).extract()
                }
            }
            ShareLink(items: selection.compactMap(\.id.diskURL)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(selection.isEmpty)
            .help(Text("Share"))
            .padding(.horizontal, Self.spacing)
            action("Move to Trash", "trash", disabled: !browser.canTrashSelection) {
                Task { await browser.moveSelectionToTrash(undoManager: undoManager) }
            }
            action(
                "Open in Terminal", "terminal",
                disabled: !TerminalOpener.isAvailable || browser.terminalFolder == nil
            ) {
                TerminalOpener.open(browser.terminalFolder, settings: browser.settings)
            }
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            pasteboardHasFiles = FilePasteboard.hasFileURLs
        }
        .onChange(of: browser.clipboard) {
            pasteboardHasFiles = FilePasteboard.hasFileURLs
        }
    }

    /// A button with its name as label, help tag and VoiceOver name.
    private func action(
        _ title: LocalizedStringKey, _ symbol: String, disabled: Bool = false,
        run: @escaping () -> Void
    ) -> some View {
        Button(title, systemImage: symbol, action: run)
            .disabled(disabled)
            .help(Text(title))
            .padding(.horizontal, Self.spacing)
    }
}
