import SwiftUI
import TreewiseCore

/// The context menu of the items a long press or secondary click is on, or
/// of the folder when it is on empty space (ADR 0047), from `ItemCommands`.
struct ItemMenu: View {
    let items: [FileItem]
    let actions: ItemActions

    var body: some View {
        ForEach(
            Array(ItemCommands.sections(for: items, actions: actions).enumerated()), id: \.offset
        ) { _, section in
            Section {
                ForEach(section) { command in
                    Button(role: command.isDestructive ? .destructive : nil) {
                        command.perform()
                    } label: {
                        Label(command.title, systemImage: command.symbol)
                    }
                    .disabled(!command.isEnabled)
                }
            }
        }
    }
}
