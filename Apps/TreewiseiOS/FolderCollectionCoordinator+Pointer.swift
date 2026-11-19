import TreewiseCore
import TreewiseUI
import UIKit

/// The list with a trackpad or mouse, as on the Mac (ADR 0136): a click selects, ⌘ and ⇧
/// extend, a click on empty space clears, a double click opens, a right-click selects the row
/// it is on, and a rectangle dragged over empty space selects the rows it touches.
extension FolderCollectionCoordinator {
    func attachPointer(to view: UICollectionView) {
        let emptyClick = UITapGestureRecognizer(
            target: self, action: #selector(clickedEmptySpace(_:)))
        let doubleClick = UITapGestureRecognizer(target: self, action: #selector(doubleClicked(_:)))
        doubleClick.numberOfTapsRequired = 2
        for click in [emptyClick, doubleClick] {
            click.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
            click.cancelsTouchesInView = false
            view.addGestureRecognizer(click)
        }
        let band = UIBandSelectionInteraction { [weak self] band in self?.banded(band) }
        band.shouldBeginHandler = { [weak view] _, point in
            view?.indexPathForItem(at: point) == nil
        }
        view.addInteraction(band)
    }

    /// Whether the touch that just began on `view` is the pointer's.
    func isPointerTouch(in view: UICollectionView) -> Bool {
        (view as? FolderCollectionView)?.isPointerTouch == true
    }

    func collectionView(_ view: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        clickWithPointer(at: indexPath, in: view)
    }

    func collectionView(_ view: UICollectionView, shouldDeselectItemAt indexPath: IndexPath)
        -> Bool
    {
        clickWithPointer(at: indexPath, in: view)
    }

    /// Selects as a click does, and tells UIKit to leave the row alone; a finger's tap, and a
    /// click while the user selects (ADR 0124), go on as UIKit does them.
    private func clickWithPointer(at indexPath: IndexPath, in view: UICollectionView) -> Bool {
        guard let collection = view as? FolderCollectionView, collection.isPointerTouch,
            !view.isEditing, let row = item(at: indexPath)?.id
        else { return true }
        apply { $0.clicked(row, modifiers: Self.modifiers(collection.pointerModifiers), in: $1) }
        return false
    }

    @objc private func clickedEmptySpace(_ click: UITapGestureRecognizer) {
        guard let view = click.view as? FolderCollectionView, !view.isEditing,
            view.indexPathForItem(at: click.location(in: view)) == nil
        else { return }
        apply { $0.clicked(nil, modifiers: Self.modifiers(view.pointerModifiers), in: $1) }
    }

    @objc private func doubleClicked(_ click: UITapGestureRecognizer) {
        guard let view = click.view as? UICollectionView, !view.isEditing,
            let row = item(at: view.indexPathForItem(at: click.location(in: view)))
        else { return }
        content?.actions.open(row)
    }

    /// Selects the row a right-click is on before its menu shows, unless it is selected.
    func rightClicked(_ row: FileItem.ID, in view: UICollectionView) {
        guard isPointerTouch(in: view), !view.isEditing else { return }
        apply { selection, _ in selection.rightClicked(row) }
    }

    private func banded(_ band: UIBandSelectionInteraction) {
        guard let view, !view.isEditing else { return }
        switch band.state {
        case .began:
            bandStart = currentSelection
        case .selecting, .ended:
            guard let rect = band.selectionRect else { return }
            let touched = (view.collectionViewLayout.layoutAttributesForElements(in: rect) ?? [])
                .compactMap { item(at: $0.indexPath)?.id }
            let start = bandStart ?? currentSelection
            set(start.banded(Set(touched), modifiers: Self.modifiers(band.initialModifierFlags)))
        default:
            break
        }
    }

    /// The browser's selection, with the anchor of the last click.
    private var currentSelection: PointerSelection {
        guard let browser = content?.browser else { return PointerSelection() }
        let selected = browser.content(of: browser.layout.focusedPane.activeTabID).selection
        return PointerSelection(selection: selected, anchor: pointer.anchor)
    }

    private func apply(_ change: (PointerSelection, [FileItem.ID]) -> PointerSelection) {
        set(change(currentSelection, content?.items.map(\.id) ?? []))
    }

    private func set(_ selection: PointerSelection) {
        guard let browser = content?.browser else { return }
        pointer = selection
        browser.setSelection(selection.selection, in: browser.layout.focusedPane.activeTabID)
    }

    private static func modifiers(_ flags: UIKeyModifierFlags) -> PointerSelection.Modifiers {
        var modifiers: PointerSelection.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }
}
