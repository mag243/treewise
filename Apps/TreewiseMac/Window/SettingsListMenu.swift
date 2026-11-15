import AppKit

/// The context menu of a list in Settings (ADR 0105): it chooses the row clicked, then asks
/// `items` what can be done to it, as the list's buttons do. Kept by the list's owner.
@MainActor
final class SettingsListMenu: NSObject, NSMenuDelegate {
    private weak var table: NSTableView?
    private let items: (Int) -> [NSMenuItem]

    /// A menu for `table` whose items `items` gives for the row clicked.
    init(for table: NSTableView, items: @escaping (Int) -> [NSMenuItem]) {
        self.table = table
        self.items = items
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        table.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let table, table.clickedRow >= 0 else { return }
        let row = table.clickedRow
        if !table.selectedRowIndexes.contains(row) {
            table.selectRowIndexes([row], byExtendingSelection: false)
        }
        for item in items(row) { menu.addItem(item) }
    }
}
