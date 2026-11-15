import AppKit
import TreewiseCore
import TreewiseUI

/// Add Missing Folders from 2026… on a year's own folder, and the sheet that makes the
/// folders of the year before it lacks (ADR 0102). Paid, like the bar: it shows only while
/// the add-on may work.
extension FolderTemplateMenu {
    /// Add Missing Folders from 2026…, for `folder` when it is a year's own folder.
    static func missingItem(
        for folder: FileItem.ID, browser: BrowserState, undoManager: UndoManager?,
        enabled: Bool = true
    ) -> NSMenuItem? {
        guard FolderTemplatesService.addOnMayWork, let year = YearFolders.ownYear(of: folder),
            let before = YearFolders.folderBefore(folder)
        else { return nil }
        let item = ClosureMenuItem(
            String(localized: "Add Missing Folders from \(String(year - 1))…"),
            symbol: "folder.badge.questionmark"
        ) {
            guard let window = NSApp.keyWindow else { return }
            Task {
                await addMissing(
                    in: folder, from: before, browser: browser, on: window,
                    undoManager: undoManager)
            }
        }
        item.isEnabled = enabled
        return item
    }

    private static func addMissing(
        in folder: FileItem.ID, from before: FileItem.ID, browser: BrowserState,
        on window: NSWindow, undoManager: UndoManager?
    ) async {
        let fileSystem = browser.fileSystem
        guard let item = try? await fileSystem.item(at: folder) else { return }
        let bar = FolderTemplatesService.bar(for: browser)
        if let offer = await bar.missing(in: item, all: true) {
            return presentMissing(offer, browser: browser, on: window, undoManager: undoManager)
        }
        let alert = NSAlert()
        let name = TemplateBarView.name(of: before)
        if (try? await fileSystem.item(at: before)) == nil {
            alert.messageText = String(localized: "There is no folder \(name)")
            alert.informativeText = String(
                localized: "Missing folders come from the same folder a year before.")
        } else {
            alert.messageText = String(localized: "No folders are missing")
            alert.informativeText = String(
                localized: "\(item.name) has every folder of \(name).")
        }
        alert.beginSheetModal(for: window) { _ in }
    }

    /// Opens the sheet that makes the folders `offer` lacks in its year's folder.
    static func presentMissing(
        _ offer: TemplateBarModel.MissingOffer, browser: BrowserState, on window: NSWindow,
        undoManager: UndoManager?
    ) {
        let name = TemplateBarView.name(of: offer.yearBefore)
        FolderTemplateSheet.present(
            .init(
                title: String(localized: "Add the Missing Folders of \(name)"),
                tree: offer.missing.tree, templateID: nil, place: .filling(offer.folder)),
            browser: browser, on: window, undoManager: undoManager)
    }
}
