import SwiftUI
import TreewiseCore
import TreewiseUI

/// The toolbar's buttons while the user selects (ADR 0124): the selection's commands, as in
/// the context menu, Select All or Deselect All, and Done, which ends selecting.
struct SelectionButtons: View {
    let browser: BrowserState
    let actions: ItemActions
    /// The items the folder shows, which Select All selects.
    let items: [FileItem]
    @Binding var isSelecting: Bool

    private var tab: TabModel.ID { browser.layout.focusedPane.activeTabID }
    private var selection: Set<FileItem.ID> { browser.content(of: tab).selection }
    private var selected: [FileItem] { items.filter { selection.contains($0.id) } }
    private var isAllSelected: Bool { !items.isEmpty && selected.count == items.count }

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
        Button(isAllSelected ? "Deselect All" : "Select All") {
            browser.setSelection(isAllSelected ? [] : Set(items.map(\.id)), in: tab)
        }
        Button("Done") { isSelecting = false }
            .fontWeight(.semibold)
    }
}
