import AppKit
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI
import UniformTypeIdentifiers

/// Drops a drag's items on a folder, with the modifiers held at the drop, and
/// returns when the move or copy is done.
typealias DropAction = (_ items: [FileItem], _ target: FileItem, _ modifiers: DropModifiers) async
    -> Void

/// What a drag on its way to a drop target carries and what dropping it would
/// do (ADR 0003). Drags from Treewise and from Finder take the same route: both
/// put file URLs on the drag pasteboard, which every drop target reads here.
/// Files other apps promise to write go to `PromisedDrop` (ADR 0020).
@MainActor
enum DropRouting {
    /// What the list and the sidebar take: file URLs and file promises.
    static let pasteboardTypes =
        [NSPasteboard.PasteboardType.fileURL] + PromisedDrop.pasteboardTypes
    /// What the address bar takes, as SwiftUI knows the types.
    static let contentTypes = [UTType.fileURL] + PromisedDrop.contentTypes

    /// Reads with the window's boundary, so items from outside it never drop in (ADR 0019).
    private static let fileSystem = LocalFileSystem(locations: LaunchOptions.locations)
    /// The drag in progress, keyed by its pasteboard's change count, because
    /// AppKit asks again every time the pointer moves.
    private static var cached: (changeCount: Int, session: TreewiseUI.DragSession?)?

    /// The modifiers held now, as the drag rules know them.
    static var modifiers: DropModifiers {
        let flags = NSEvent.modifierFlags
        var modifiers: DropModifiers = []
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.command) { modifiers.insert(.command) }
        return modifiers
    }

    /// The items on a drag pasteboard, or `nil` when it holds no files or
    /// any file that cannot be read, such as one outside the boundary: a drag
    /// drops whole or not at all, as the drag rules say for invalid items.
    static func session(of pasteboard: NSPasteboard) -> TreewiseUI.DragSession? {
        if let cached, cached.changeCount == pasteboard.changeCount { return cached.session }
        let urls = FilePasteboard.fileURLs(on: pasteboard)
        let items = urls.compactMap { item(at: FileItem.ID($0.standardizedFileURL.path)) }
        let session =
            items.isEmpty || items.count != urls.count
            ? nil : TreewiseUI.DragSession(items: items, ancestry: { LocalFileSystem.ancestry($0) })
        cached = (pasteboard.changeCount, session)
        return session
    }

    /// Reads a drop target or a dragged item from disk, at once.
    static func item(at id: FileItem.ID) -> FileItem? {
        try? fileSystem.currentItem(at: id)
    }

    /// Whether the drag would move or copy onto `target`, showing the badge
    /// next to the pointer; `nil`, with the badge hidden, when it cannot drop there.
    static func mode(of pasteboard: NSPasteboard, over target: FileItem?) -> TransferMode? {
        guard let target, let badge = badge(of: pasteboard, over: target) else {
            finish()
            return nil
        }
        DragBadgePanel.shared.show(badge, at: NSEvent.mouseLocation)
        return badge.mode
    }

    /// The operation AppKit should show for the drag over `target`.
    static func operation(of info: any NSDraggingInfo, over target: FileItem?) -> NSDragOperation {
        guard let mode = mode(of: info.draggingPasteboard, over: target) else { return [] }
        let mask = info.draggingSourceOperationMask
        // AppKit narrows the source's mask while a modifier is held: ⌥ leaves
        // only copy, ⌘ only generic, which is how a forced move reaches us.
        switch mode {
        case .move: return mask.contains(.move) ? .move : mask.contains(.generic) ? .generic : []
        case .copy: return mask.contains(.copy) ? .copy : []
        }
    }

    /// Drops the drag on `target`. Returns `false` when it cannot drop there.
    static func perform(_ pasteboard: NSPasteboard, on target: FileItem?, with drop: DropAction?)
        -> Bool
    {
        finish()
        guard let target, let drop, badge(of: pasteboard, over: target) != nil else { return false }
        guard let session = session(of: pasteboard) else {
            return PromisedDrop.receive(pasteboard, into: target, with: drop)
        }
        let modifiers = modifiers
        Task { await drop(session.items, target, modifiers) }
        return true
    }

    /// The badge for dragged items, or for promised files, over `target`.
    private static func badge(of pasteboard: NSPasteboard, over target: FileItem)
        -> TreewiseUI.DragSession.Badge?
    {
        if let session = session(of: pasteboard) {
            return session.badge(over: target, modifiers: modifiers)
        }
        return PromisedDrop.isPromised(pasteboard)
            ? TreewiseUI.DragSession.promisedBadge(over: target) : nil
    }

    /// Hides the badge: the drag left the target, dropped or ended.
    static func finish() {
        DragBadgePanel.shared.hide()
    }

    /// The drop action of a window: the items go through the browser's drag
    /// rules, with conflicts asked in a dialog and undo in the window's menu.
    static func action(for browser: BrowserState, undoManager: UndoManager?) -> DropAction {
        { items, target, modifiers in
            await browser.drop(
                items, onto: target, modifiers: modifiers, resolver: AlertConflictResolver(),
                undoManager: undoManager)
        }
    }
}
