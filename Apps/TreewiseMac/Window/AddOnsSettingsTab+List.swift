import AppKit
import TreewiseModuleInterface
import TreewiseUI

/// The list of cards: a card per add-on, the selected one open (ADR 0092), dragged or
/// moved by accessibility actions to set the order (ADR 0070).
extension AddOnsSettingsTab {
    func numberOfRows(in tableView: NSTableView) -> Int {
        shown.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let module = shown[row]
        let id = module.id
        let catalog = catalog
        let settings = settings
        let defaultID = NameModuleDescription.defaultID(among: modules)
        let inNewFolders = working.filter {
            settings.addOns.isOnInNewFolders($0, defaultID: defaultID)
        }
        let card = AddOnCard(
            isOnSetting: settings.addOns.isOn(id), licence: states[id],
            isLastWorking: working == [id], isLastInNewFolders: inNewFolders == [id])
        let view = AddOnCardView(
            module: module, card: card, licence: states[id], isSelected: id == selectedID,
            isOnInNewFolders: settings.addOns.isOnInNewFolders(id, defaultID: defaultID),
            width: Self.width,
            actions: .init(
                turnOn: { settings.addOns.setOn(id, on: $0, catalog: catalog) },
                turnOnInNewFolders: {
                    settings.addOns.setOnInNewFolders(
                        id, on: $0, catalog: catalog, defaultID: defaultID)
                },
                startTrial: { [weak self] in
                    self?.licences.startTrial(of: id)
                    self?.load()
                }))
        view.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: String(localized: "Move Up")) { [weak self] in
                self?.move(id, to: row - 1)
                return true
            },
            NSAccessibilityCustomAction(name: String(localized: "Move Down")) { [weak self] in
                self?.move(id, to: row + 1)
                return true
            },
        ])
        return view
    }

    /// Opens the card chosen, folds the one before and shows it whole (ADR 0092).
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        guard row >= 0, row < shown.count, shown[row].id != selectedID else { return }
        let before = shown.firstIndex { $0.id == selectedID }
        selectedID = shown[row].id
        // Only the two cards that change are made again, so a drag that starts here goes on.
        var changed = IndexSet(integer: row)
        if let before { changed.insert(before) }
        table.reloadData(forRowIndexes: changed, columnIndexes: [0])
        revealSelection()
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int)
        -> (any NSPasteboardWriting)?
    {
        let item = NSPasteboardItem()
        item.setString(shown[row].id, forType: Self.dragType)
        return item
    }

    func tableView(
        _ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard info.draggingSource as? NSTableView === table else { return [] }
        tableView.setDropRow(row, dropOperation: .above)
        return .move
    }

    func tableView(
        _ tableView: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard
            let id = info.draggingPasteboard.pasteboardItems?.first?.string(
                forType: Self.dragType),
            let from = shown.firstIndex(where: { $0.id == id })
        else { return false }
        move(id, to: row > from ? row - 1 : row)
        return true
    }
}
