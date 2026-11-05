import SwiftUI
import TreewiseCore

/// The context menu of the items a long press or secondary click is on, or
/// of the folder when it is on empty space (ADR 0047).
struct ItemMenu: View {
    let items: [FileItem]
    let actions: ItemActions

    var body: some View {
        if items.isEmpty {
            folderCommands
        } else {
            itemCommands
        }
    }

    @ViewBuilder private var itemCommands: some View {
        if let item = items.first, items.count == 1 {
            Button {
                actions.open(item)
            } label: {
                if item.isContainer {
                    Label("Open", systemImage: "folder")
                } else {
                    Label("Quick Look", systemImage: "eye")
                }
            }
            Button {
                actions.rename(item)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .disabled(!item.canBeRenamedOrTrashed)
        }
        Section {
            Button {
                actions.cut(items)
            } label: {
                Label("Cut", systemImage: "scissors")
            }
            .disabled(!items.allSatisfy(\.isMovable))
            Button {
                actions.copy(items)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(!items.allSatisfy(\.isMovable))
        }
        Button(role: .destructive) {
            actions.moveToTrash(items)
        } label: {
            Label("Move to Trash", systemImage: "trash")
        }
        .disabled(!items.allSatisfy(\.canBeRenamedOrTrashed))
    }

    @ViewBuilder private var folderCommands: some View {
        Button(action: actions.newFolder) {
            Label("New Folder", systemImage: "folder.badge.plus")
        }
        .disabled(!actions.canAddItems)
        Button(action: actions.paste) {
            Label("Paste", systemImage: "doc.on.clipboard")
        }
        .disabled(!actions.canPaste)
    }
}
