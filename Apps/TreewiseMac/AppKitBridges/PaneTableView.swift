import AppKit
import Quartz
import TreewiseUI

/// What the list's keyboard and Edit-menu commands do.
struct TableCommands {
    var cut: () -> Void
    var copy: () -> Void
    var paste: () -> Void
    var rename: (_ row: Int) -> Void
    var canPaste: () -> Bool
    /// The context menu for a clicked row, or for empty space when `nil`.
    var menu: (_ row: Int?) -> NSMenu?
    /// The files of the selected rows, for Quick Look.
    var selectedURLs: () -> [URL]
}

/// The list's table view. It tells its pane when it takes the keyboard focus,
/// draws its selection in the accent color only while its pane is the active
/// one (PLAN.md §4.4), and answers Cut, Copy and Paste from the Edit menu,
/// Return for Rename (ADR 0018) and a click on the selected name (ADR 0039).
final class PaneTableView: NSTableView, NSMenuItemValidation {
    /// Return and Enter: rename the selected item.
    private static let renameKeyCodes: Set<UInt16> = [36, 76]
    /// Space: Quick Look.
    private static let quickLookKeyCode: UInt16 = 49

    /// Called when the table becomes the first responder.
    var onFocus: (() -> Void)?
    /// The commands the list answers.
    var commands: TableCommands?
    private let pendingRename = PendingRename()

    /// Whether this table's pane is the active pane of the window.
    var isActivePane = true {
        didSet {
            guard oldValue != isActivePane else { return }
            enumerateAvailableRowViews { rowView, _ in rowView.needsDisplay = true }
        }
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?() }
        return accepted
    }

    /// Any click makes the pane active, also on empty rows below the last
    /// item, where AppKit selects nothing and may not move the focus.
    /// A click on the name of the only selected row renames it after the wait.
    override func mouseDown(with event: NSEvent) {
        pendingRename.cancel()
        pendingRename.dragged = false
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        let wasOnlySelection = row >= 0 && selectedRowIndexes == IndexSet(integer: row)
        let isOnName = row >= 0 && self.isOnName(point, row: row)
        if window?.firstResponder !== self { window?.makeFirstResponder(self) }
        onFocus?()
        // AppKit tracks the mouse until it goes up or a drag ends.
        super.mouseDown(with: event)
        let click = ClickRename(
            wasOnlySelection: wasOnlySelection, isOnName: isOnName,
            clickCount: event.clickCount, hasModifiers: PendingRename.hasModifiers(event),
            dragged: pendingRename.dragged)
        pendingRename.schedule(
            click,
            isStillValid: { [weak self] in
                self?.window?.isKeyWindow == true
                    && self?.selectedRowIndexes == IndexSet(integer: row)
            },
            rename: { [weak self] in self?.commands?.rename(row) })
    }

    override func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        pendingRename.dragged = true
        super.draggingSession(session, willBeginAt: screenPoint)
    }

    /// Whether `point` is on the text of the row's name.
    private func isOnName(_ point: NSPoint, row: Int) -> Bool {
        guard let cell = view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
            let field = cell.textField
        else { return false }
        return PendingRename.isOnText(field.convert(point, from: self), in: field)
    }

    override func keyDown(with event: NSEvent) {
        pendingRename.cancel()
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if Self.renameKeyCodes.contains(event.keyCode), modifiers.isEmpty,
            selectedRowIndexes.count == 1
        {
            commands?.rename(selectedRow)
        } else if event.keyCode == Self.quickLookKeyCode, modifiers.isEmpty {
            QuickLookSource.shared.toggle(commands?.selectedURLs() ?? [])
        } else {
            super.keyDown(with: event)
        }
    }

    /// A right-click on a row outside the selection selects that row first, as
    /// in Finder; a click on empty space clears the selection.
    override func menu(for event: NSEvent) -> NSMenu? {
        let row = self.row(at: convert(event.locationInWindow, from: nil))
        if row >= 0, !selectedRowIndexes.contains(row) {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else if row < 0 {
            deselectAll(nil)
        }
        return commands?.menu(row >= 0 ? row : nil)
    }

    // The list answers for Quick Look while it has the keyboard focus.
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
        case #selector(cut(_:)), #selector(copy(_:)): !selectedRowIndexes.isEmpty
        case #selector(paste(_:)): commands?.canPaste() ?? false
        default: true
        }
    }
}

/// A row that follows its pane rather than the keyboard focus for the
/// selection color: AppKit draws an emphasized selection in the accent color.
final class PaneRowView: NSTableRowView {
    weak var table: PaneTableView?

    override var isEmphasized: Bool {
        get { table?.isActivePane ?? true }
        set {}  // AppKit sets this from the keyboard focus; the pane decides instead.
    }
}
