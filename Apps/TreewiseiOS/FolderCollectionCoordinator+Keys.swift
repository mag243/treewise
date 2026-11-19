import TreewiseCore
import TreewiseUI
import UIKit

/// The keyboard's commands on the list (ADR 0135): they act on the selection, as the Mac's
/// menus do, and on nothing while the window shows a sheet or an alert.
extension FolderCollectionCoordinator {
    private var browser: BrowserState? { content?.browser }
    private var actions: ItemActions? { content?.actions }
    private var isActive: Bool { content.map { !$0.isPresenting } ?? false }
    private var selected: [FileItem] { browser?.selectedItems ?? [] }
    private var single: FileItem? { selected.count == 1 ? selected.first : nil }

    /// Whether `action` is one of the keyboard's commands on the list.
    func handles(_ action: Selector) -> Bool {
        checks[action] != nil
    }

    /// Whether the list can carry out `action` now.
    func canPerform(_ action: Selector) -> Bool {
        guard isActive, let check = checks[action] else { return false }
        return check()
    }

    /// What each of the keyboard's commands needs.
    private var checks: [Selector: () -> Bool] {
        guard let browser, let actions else { return [:] }
        return [
            #selector(UIResponderStandardEditActions.cut(_:)): { browser.canCutSelection },
            #selector(UIResponderStandardEditActions.copy(_:)): { browser.canCopySelection },
            #selector(UIResponderStandardEditActions.paste(_:)): { actions.canPaste },
            #selector(UIResponderStandardEditActions.selectAll(_:)): {
                !(self.content?.items.isEmpty ?? true)
            },
            #selector(UIResponder.find(_:)): { true },
            #selector(UIResponder.toggleSidebar(_:)): { true },
            #selector(FolderCollectionView.openSelection(_:)): { self.single != nil },
            #selector(FolderCollectionView.openSelectionInNewWindow(_:)): {
                self.single?.isContainer == true && actions.openInNewWindow != nil
            },
            #selector(FolderCollectionView.renameSelection(_:)): {
                self.single?.canBeRenamedOrTrashed == true
            },
            #selector(FolderCollectionView.moveSelectionToTrash(_:)): {
                !self.selected.isEmpty && self.selected.allSatisfy(\.canBeRenamedOrTrashed)
            },
            #selector(FolderCollectionView.moveItemHere(_:)): {
                browser.clipboard != nil && browser.canAddItems
            },
        ]
    }

    func moveSelection(_ direction: KeyboardSelection.Direction, extending: Bool) {
        guard isActive, let browser, let content else { return }
        let tab = browser.layout.focusedPane.activeTabID
        let current = browser.content(of: tab).selection
        let start = keyboard.selection == current ? keyboard : KeyboardSelection(selection: current)
        keyboard = start.moved(direction, in: content.items.map(\.id), extending: extending)
        browser.setSelection(keyboard.selection, in: tab)
        if let cursor = keyboard.cursor,
            let index = content.items.firstIndex(where: { $0.id == cursor })
        {
            view?.scrollToItem(
                at: IndexPath(item: index, section: 0), at: [], animated: true)
        }
    }

    func quickLook() {
        guard isActive, let item = single, !item.isContainer else { return }
        actions?.open(item)
    }

    func find() {
        guard isActive else { return }
        content?.find()
    }

    func toggleSidebar() {
        guard isActive else { return }
        content?.toggleSidebar()
    }

    func stopSelecting() {
        guard isActive else { return }
        content?.endSelecting()
    }

    func goToEnclosingFolder() {
        guard isActive, let browser else { return }
        Task { await browser.goUp(pane: 0) }
    }

    func cut() {
        guard canPerform(#selector(UIResponderStandardEditActions.cut(_:))) else { return }
        browser?.cutSelection()
    }

    func copy() {
        guard canPerform(#selector(UIResponderStandardEditActions.copy(_:))) else {
            return
        }
        browser?.copySelection()
    }

    func paste() {
        guard isActive, actions?.canPaste == true else { return }
        actions?.paste()
    }

    func selectAll() {
        guard isActive, let browser, let content else { return }
        browser.setSelection(
            Set(content.items.map(\.id)), in: browser.layout.focusedPane.activeTabID)
    }

    func openSelection() {
        guard isActive, let item = single else { return }
        actions?.open(item)
    }

    func openSelectionInNewWindow() {
        guard isActive, let item = single, item.isContainer else { return }
        actions?.openInNewWindow?(item)
    }

    func renameSelection() {
        guard isActive, let item = single, item.canBeRenamedOrTrashed else { return }
        actions?.rename(item)
    }

    func moveSelectionToTrash() {
        guard canPerform(#selector(FolderCollectionView.moveSelectionToTrash(_:))) else {
            return
        }
        actions?.moveToTrash(selected)
    }

    func moveItemHere() {
        guard canPerform(#selector(FolderCollectionView.moveItemHere(_:))),
            let browser, let actions
        else { return }
        Task {
            await browser.moveHere(
                resolver: actions.conflicts.resolver(), undoManager: actions.undoManager)
        }
    }
}
