import SwiftUI
import TreewiseCore
import TreewiseUI

/// The selection's commands, as in the context menu (ADR 0124).
struct SelectionActionsMenu: View {
    let selected: [FileItem]
    let actions: ItemActions

    var body: some View {
        Menu {
            ForEach(
                Array(ItemCommands.sections(for: selected, actions: actions).enumerated()),
                id: \.offset
            ) { _, section in
                Section {
                    ForEach(section) { ItemCommandEntry(command: $0) }
                }
            }
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
        }
        .disabled(selected.isEmpty)
    }
}

/// One command of a menu: a button, or the submenu of its children (ADR 0142).
struct ItemCommandEntry: View {
    let command: ItemCommand

    var body: some View {
        if command.children.isEmpty {
            Button(
                role: command.isDestructive ? .destructive : nil, action: command.perform
            ) {
                Label(command.title, systemImage: command.symbol)
            }
            .disabled(!command.isEnabled)
        } else {
            Menu {
                // A submenu holds entries of the same kind, which a view's type cannot
                // hold of itself.
                ForEach(command.children) { AnyView(ItemCommandEntry(command: $0)) }
            } label: {
                Label(command.title, systemImage: command.symbol)
            }
        }
    }
}
