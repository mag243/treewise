import AppKit
import TreewiseCore
import TreewiseUI

/// Extracting and compressing the window's selection, shared by the File menu,
/// the context menu and the command bar (ADR 0074).
@MainActor
struct ArchiveCommands {
    let browser: BrowserState
    let undoManager: UndoManager?

    /// Asks where to extract the archive, starting at the folder it is in,
    /// and extracts it to a new folder there.
    func extract() {
        Task {
            guard let archive = await browser.archiveToExtract(), let parent = archive.parentID
            else { return }
            askWhereToExtract(archive, startingAt: parent)
        }
    }

    private func askWhereToExtract(_ archive: FileItem, startingAt parent: FileItem.ID) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = parent.diskURL
        panel.prompt = String(localized: "Extract")
        panel.message = String(localized: "Choose where to extract “\(archive.name)”.")
        let finish: (NSApplication.ModalResponse) -> Void = { [browser, undoManager] response in
            guard response == .OK, let folder = panel.url else { return }
            let destination = FileItem.ID(folder.standardizedFileURL.path)
            Task { await browser.extractSelection(to: destination, undoManager: undoManager) }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            panel.begin(completionHandler: finish)
        }
    }

    /// Compresses the selection to a new archive beside it.
    func compress(to format: ArchiveFormat) {
        Task { await browser.compressSelection(to: format, undoManager: undoManager) }
    }
}
