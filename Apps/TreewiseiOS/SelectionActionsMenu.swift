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
                    ForEach(section) { command in
                        Button(
                            role: command.isDestructive ? .destructive : nil,
                            action: command.perform
                        ) {
                            Label(command.title, systemImage: command.symbol)
                        }
                        .disabled(!command.isEnabled)
                    }
                }
            }
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
        }
        .disabled(selected.isEmpty)
    }
}
