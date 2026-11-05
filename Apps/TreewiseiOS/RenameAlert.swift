import SwiftUI
import TreewiseCore
import TreewiseUI

/// Asks for the new name of the item `BrowserState.renameRequest` names: from
/// Rename, and for a new folder (ADR 0047).
struct RenameAlert: ViewModifier {
    let browser: BrowserState
    let items: [FileItem]
    let undoManager: UndoManager?
    @State private var name = ""

    private var item: FileItem? {
        browser.renameRequest.flatMap { request in items.first { $0.id == request } }
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: browser.renameRequest, initial: true) {
                name = item?.name ?? ""
            }
            .alert(
                "Rename",
                isPresented: Binding(
                    get: { item != nil },
                    set: { if !$0 { browser.renameRequest = nil } })
            ) {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Rename") { rename() }
                Button("Cancel", role: .cancel) {}
            }
    }

    private func rename() {
        guard let item else { return }
        let newName = name
        Task { await browser.rename(item, to: newName, undoManager: undoManager) }
    }
}
