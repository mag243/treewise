import SwiftUI
import TreewiseCore
import TreewiseUI

/// A name asked for, for `sheet(item:)`: an item's new name, or a new folder's name
/// before the folder is made (ADR 0130).
struct NameSheetRequest: Identifiable {
    enum Purpose {
        case rename(FileItem)
        case newFolder
    }

    let id = UUID()
    let purpose: Purpose
    /// The name the field starts with.
    let name: String
    /// Whether the proposals are asked for at once, as Rename with Suggestions does.
    var suggests = false
}

/// Asks for a name (ADR 0130): the field, and for a file being renamed the add-ons'
/// proposals beneath it, asked with Show Suggestions, ⌥Esc or F5, as the Mac's suggestion
/// list asks them (ADR 0066). A proposal only goes into the field; Rename renames.
struct NameSheet: View {
    let request: NameSheetRequest
    let browser: BrowserState
    let undoManager: UndoManager
    /// Opens the name overview of the file.
    let openOverview: (FileItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var proposals = NameProposalsAsked()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NameTextField(
                        text: $name, selectsBaseName: !isNewFolder, onKey: handle,
                        onSubmit: confirm)
                }
                if let item = suggestible {
                    NameSheetProposals(
                        proposals: proposals, name: $name, ask: { ask(for: item) },
                        openOverview: {
                            dismiss()
                            openOverview(item)
                        })
                }
            }
            .navigationTitle(isNewFolder ? Text("New Folder") : Text("Rename"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNewFolder ? "Create" : "Rename") { confirm() }
                        .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            name = request.name
            if request.suggests, let item = suggestible { ask(for: item) }
        }
        .onDisappear { proposals.stop() }
    }

    private var isNewFolder: Bool {
        if case .newFolder = request.purpose { return true }
        return false
    }

    /// The file being renamed, when its add-ons can propose names for it.
    private var suggestible: FileItem? {
        guard case .rename(let item) = request.purpose, browser.canSuggestName(for: item)
        else { return nil }
        return item
    }

    private func handle(_ key: NameTextField.Key) {
        switch key {
        case .suggest:
            if let item = suggestible { ask(for: item) }
        case .previous:
            if let option = proposals.step(by: -1) { name = option.name }
        case .next:
            if let option = proposals.step(by: 1) { name = option.name }
        }
    }

    private func ask(for item: FileItem) {
        guard proposals.state == .notAsked else { return }
        Task { await proposals.ask(for: item, in: browser) }
    }

    private func confirm() {
        guard !name.isEmpty else { return }
        let typed = name
        switch request.purpose {
        case .rename(let item):
            Task { await browser.rename(item, to: typed, undoManager: undoManager) }
        case .newFolder:
            Task { await browser.newFolder(named: typed, undoManager: undoManager) }
        }
        dismiss()
    }
}
