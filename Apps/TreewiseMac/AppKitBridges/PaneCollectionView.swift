import AppKit
import Quartz
import TreewiseUI

/// The icon view's collection view, with the list's keys and commands
/// (ADR 0025): it tells its pane when it takes the keyboard focus, opens a
/// double-clicked tile, answers Cut, Copy and Paste from the Edit menu,
/// Return for Rename, a click on the selected name (ADR 0039) and Space for
/// Quick Look, and gives a context menu.
/// `TableCommands` count tiles where the list counts rows.
final class PaneCollectionView: NSCollectionView, NSMenuItemValidation {
    /// Return and Enter: rename the selected item.
    private static let renameKeyCodes: Set<UInt16> = [36, 76]
    /// Space: Quick Look.
    private static let quickLookKeyCode: UInt16 = 49
    private static let doubleClick = 2

    /// Called when the view becomes the first responder.
    var onFocus: (() -> Void)?
    /// Called with a double-clicked tile.
    var onOpen: ((Int) -> Void)?
    /// Called when the view changes the selection itself, for a context menu.
    var onSelect: (() -> Void)?
    /// The commands the view answers.
    var commands: TableCommands?
    private let pendingRename = PendingRename()

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?() }
        return accepted
    }

    /// Any click makes the pane active, also on empty space between tiles. A
    /// click on the name of the only selected tile renames it after the wait.
    override func mouseDown(with event: NSEvent) {
        pendingRename.cancel()
        pendingRename.dragged = false
        let index = tile(at: event)
        let path = index.map { IndexPath(item: $0, section: 0) }
        let wasOnlySelection = path.map { selectionIndexPaths == [$0] } ?? false
        let isOnName = index.map { isOnName(event, tile: $0) } ?? false
        if window?.firstResponder !== self { window?.makeFirstResponder(self) }
        onFocus?()
        super.mouseDown(with: event)
        guard let index, let path else { return }
        if event.clickCount == Self.doubleClick { onOpen?(index) }
        let click = ClickRename(
            wasOnlySelection: wasOnlySelection, isOnName: isOnName,
            clickCount: event.clickCount, hasModifiers: PendingRename.hasModifiers(event),
            dragged: pendingRename.dragged)
        pendingRename.schedule(
            click,
            isStillValid: { [weak self] in
                self?.window?.isKeyWindow == true && self?.selectionIndexPaths == [path]
            },
            rename: { [weak self] in self?.commands?.rename(index) })
    }

    override func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        pendingRename.dragged = true
        super.draggingSession(session, willBeginAt: screenPoint)
    }

    /// Whether the pointer of `event` is on the text of the tile's name.
    private func isOnName(_ event: NSEvent, tile index: Int) -> Bool {
        guard let field = item(at: IndexPath(item: index, section: 0))?.textField else {
            return false
        }
        // The name is centered under the icon: its whole field counts.
        return field.bounds.contains(field.convert(event.locationInWindow, from: nil))
    }

    override func keyDown(with event: NSEvent) {
        pendingRename.cancel()
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let selected = selectionIndexPaths
        if Self.renameKeyCodes.contains(event.keyCode), modifiers.isEmpty, selected.count == 1,
            let index = selected.first?.item
        {
            commands?.rename(index)
        } else if event.keyCode == Self.quickLookKeyCode, modifiers.isEmpty {
            QuickLookSource.shared.toggle(commands?.selectedURLs() ?? [])
        } else {
            super.keyDown(with: event)
        }
    }

    /// A right-click on a tile outside the selection selects that tile first,
    /// as in Finder; a click on empty space clears the selection.
    override func menu(for event: NSEvent) -> NSMenu? {
        let index = tile(at: event)
        if let index, !selectionIndexPaths.contains(IndexPath(item: index, section: 0)) {
            selectionIndexPaths = [IndexPath(item: index, section: 0)]
            onSelect?()
        } else if index == nil, !selectionIndexPaths.isEmpty {
            selectionIndexPaths = []
            onSelect?()
        }
        return commands?.menu(index)
    }

    // The icon view answers for Quick Look while it has the keyboard focus.
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel?) -> Bool {
        true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel?) {
        // AppKit calls this on the main thread, as it does every responder method.
        MainActor.assumeIsolated { panel?.dataSource = QuickLookSource.shared }
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel?) {
        MainActor.assumeIsolated { panel?.dataSource = nil }
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        super.draggingExited(sender)
        DropRouting.finish()
    }

    @objc func cut(_ sender: Any?) {
        commands?.cut()
    }

    @objc func copy(_ sender: Any?) {
        commands?.copy()
    }

    @objc func paste(_ sender: Any?) {
        commands?.paste()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(cut(_:)), #selector(copy(_:)): !selectionIndexPaths.isEmpty
        case #selector(paste(_:)): commands?.canPaste() ?? false
        default: true
        }
    }

    /// The tile under the pointer of `event`, if any.
    private func tile(at event: NSEvent) -> Int? {
        indexPathForItem(at: convert(event.locationInWindow, from: nil))?.item
    }
}
