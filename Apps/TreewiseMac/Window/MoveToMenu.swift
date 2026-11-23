import AppKit
import TreewiseCore
import TreewiseUI

/// Move to ▸ and Copy to ▸, as Explorer has them (ADR 0147): the folders items were last
/// moved or copied into, the favorites, and Choose Folder…, for a window's selection. They
/// go as a drop with ⌘ or ⌥ would, through the drag rules, asking about names taken.
@MainActor
enum MoveToMenu {
    /// A menu item's icon side, in points.
    private static let iconSide: CGFloat = 16

    /// The submenu item for `mode`, filled for `browser`'s selection; greyed where the
    /// selection cannot be moved or copied.
    static func item(
        _ mode: TransferMode, browser: BrowserState, undoManager: UndoManager?
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title(of: mode), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: item.title)
        menu.items = entries(mode, browser: browser, undoManager: undoManager)
        item.submenu = menu
        item.isEnabled = canSend(mode, browser: browser)
        return item
    }

    /// The submenu's items: the recent targets, the favorites, and Choose Folder…, with a
    /// line between the groups there are.
    static func entries(
        _ mode: TransferMode, browser: BrowserState, undoManager: UndoManager?
    ) -> [NSMenuItem] {
        let enabled = canSend(mode, browser: browser)
        let send: (FileItem.ID) -> Void = { folder in
            Task {
                await browser.send(
                    selectionTo: folder, mode: mode, resolver: AlertConflictResolver.make(),
                    undoManager: undoManager)
            }
        }
        let recent = browser.settings.recentTargets.folders.filter(isFolder)
        let groups: [[NSMenuItem]] = [
            recent.map { folderItem(name(of: $0), $0, enabled: enabled, send: send) },
            browser.favorites.map { folderItem($0.name, $0.id, enabled: enabled, send: send) },
            [
                ClosureMenuItem(String(localized: "Choose Folder…"), enabled: enabled) {
                    choose(mode, from: browser, send: send)
                }
            ],
        ].filter { !$0.isEmpty }
        // A menu item belongs to one menu once, so each gap gets its own separator.
        return groups.enumerated().flatMap { index, group in
            index == 0 ? group : [NSMenuItem.separator()] + group
        }
    }

    /// The title of the submenu for `mode`.
    static func title(of mode: TransferMode) -> String {
        mode == .move ? String(localized: "Move to") : String(localized: "Copy to")
    }

    private static func canSend(_ mode: TransferMode, browser: BrowserState) -> Bool {
        mode == .move ? browser.canCutSelection : browser.canCopySelection
    }

    private static func folderItem(
        _ title: String, _ folder: FileItem.ID, enabled: Bool,
        send: @escaping (FileItem.ID) -> Void
    ) -> NSMenuItem {
        let item = ClosureMenuItem(title, enabled: enabled) { send(folder) }
        let icon = ItemIcon.image(for: folder)
        icon.size = NSSize(width: iconSide, height: iconSide)
        item.image = icon
        return item
    }

    /// A recent target that is still a folder on disk.
    private static func isFolder(_ id: FileItem.ID) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: id.rawValue, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private static func name(of id: FileItem.ID) -> String {
        FileManager.default.displayName(atPath: id.rawValue)
    }

    /// Choose Folder…: a folder picker starting at the folder shown, as a sheet of the
    /// window in front.
    private static func choose(
        _ mode: TransferMode, from browser: BrowserState,
        send: @escaping (FileItem.ID) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = mode == .move ? String(localized: "Move") : String(localized: "Copy")
        panel.directoryURL = URL(
            fileURLWithPath: browser.layout.focusedPane.activeTab.folder.rawValue)
        let chosen = { (response: NSApplication.ModalResponse) in
            guard response == .OK, let url = panel.url else { return }
            send(FileItem.ID(url.standardizedFileURL.path))
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: chosen)
        } else {
            chosen(panel.runModal())
        }
    }
}

/// Fills a menu bar's Move to ▸ or Copy to ▸ for the window in front each time it opens.
@MainActor
final class MoveToMenuFiller: NSObject, NSMenuDelegate {
    private let mode: TransferMode

    init(_ mode: TransferMode) {
        self.mode = mode
    }

    /// The submenu's title.
    var title: String { MoveToMenu.title(of: mode) }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let window = NSApp.keyWindow,
            let browser = AppServices.windows.browser(of: window)
        else {
            menu.items = []
            return
        }
        menu.items = MoveToMenu.entries(mode, browser: browser, undoManager: SharedUndo.manager)
    }
}
