import SwiftUI
import TreewiseCore
import TreewiseUI

/// The folder's toolbar where the width is compact, as on the iPhone, modelled on Files
/// (ADR 0132): the enclosing folder to go up to, one menu with the folder's commands, and
/// while selecting, Select All and Done above and the selection's commands below, and else
/// while items are cut or copied, Paste below.
struct CompactFolderToolbar: ToolbarContent {
    let browser: BrowserState
    let settings: BrowserSettings
    let undo: SharedUndo
    let actions: ItemActions
    /// The items the folder shows, which Select All selects.
    let items: [FileItem]
    @Binding var isSelecting: Bool

    private var tab: TabModel.ID { browser.layout.focusedPane.activeTabID }
    private var selection: Set<FileItem.ID> { browser.content(of: tab).selection }
    private var selected: [FileItem] { items.filter { selection.contains($0.id) } }
    private var isAllSelected: Bool { !items.isEmpty && selected.count == items.count }

    var body: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                Button(isAllSelected ? "Deselect All" : "Select All") {
                    browser.setSelection(isAllSelected ? [] : Set(items.map(\.id)), in: tab)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { isSelecting = false }
                    .fontWeight(.semibold)
            }
            ToolbarItemGroup(placement: .bottomBar) { selectionBar }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                EnclosingFolderButton(browser: browser)
            }
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
            if let clipboard = browser.clipboard {
                ToolbarItemGroup(placement: .bottomBar) { pasteBar(clipboard) }
            }
        }
    }

    /// While items are cut or copied: Paste, named after what it puts here, and a button
    /// that empties the clipboard (ADR 0132).
    @ViewBuilder private func pasteBar(_ clipboard: ClipboardModel) -> some View {
        Button(role: .cancel, action: browser.emptyClipboard) {
            Label("Empty Clipboard", systemImage: "xmark.circle")
        }
        // The UI tests find it by it.
        .accessibilityIdentifier("emptyClipboard")
        Spacer()
        Button(Self.pasteTitle(clipboard), action: actions.paste)
            .fontWeight(.semibold)
            .disabled(!actions.canPaste)
            // The UI tests find it by it.
            .accessibilityIdentifier("pasteBar")
    }

    /// Paste “Notes.md” for one item, Paste 3 Items for more.
    private static func pasteTitle(_ clipboard: ClipboardModel) -> String {
        if let item = clipboard.items.first, clipboard.items.count == 1 {
            return String(localized: "Paste “\(item.name)”")
        }
        return String(localized: "Paste \(clipboard.items.count) Items")
    }

    /// Cut, Copy and Move to Trash for the selection, and the rest of its commands.
    @ViewBuilder private var selectionBar: some View {
        let movable = !selected.isEmpty && selected.allSatisfy(\.isMovable)
        Button {
            actions.cut(selected)
        } label: {
            Label("Cut", systemImage: "scissors")
        }
        .disabled(!movable)
        Button {
            actions.copy(selected)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .disabled(!movable)
        Spacer()
        Button(role: .destructive) {
            actions.moveToTrash(selected)
        } label: {
            Label("Move to Trash", systemImage: "trash")
        }
        .disabled(selected.isEmpty || !selected.allSatisfy(\.canBeRenamedOrTrashed))
        SelectionActionsMenu(selected: selected, actions: actions)
    }

    /// The folder's one menu: Select, New Folder and Paste, Undo and Redo, and the View
    /// menu's sorting and showing.
    private var moreMenu: some View {
        Menu {
            Section {
                Button {
                    isSelecting = true
                } label: {
                    Label("Select", systemImage: "checkmark.circle")
                }
                .disabled(items.isEmpty)
                Button(action: actions.newFolder) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .disabled(!actions.canAddItems)
                Button(action: actions.paste) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .disabled(!actions.canPaste)
            }
            Section {
                Button(action: undo.undo) {
                    Label(undo.undoTitle, systemImage: "arrow.uturn.backward")
                }
                .disabled(!undo.canUndo)
                Button(action: undo.redo) {
                    Label(undo.redoTitle, systemImage: "arrow.uturn.forward")
                }
                .disabled(!undo.canRedo)
            }
            Section {
                ViewMenuItems(browser: browser, settings: settings)
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
        // The UI tests find it by it.
        .accessibilityIdentifier("moreMenu")
    }
}
