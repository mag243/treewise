import SwiftUI
import TreewiseCore
import TreewiseUI

/// An add-on's Choose a Saved Pattern menu in the name overview, as the Mac's (ADR 0068):
/// the patterns found in this folder and those saved, the one in force ticked; then Save
/// Pattern…, or, once a saved pattern picked here was changed, Update “name” and Save as New
/// Pattern…; then Edit Saved Patterns….
struct NameReviewPatternMenu: View {
    let model: NameReviewModel
    let module: NameReviewModule
    /// Opens Settings' saved patterns.
    let editSaved: () -> Void
    @State private var isNaming = false
    @State private var name = ""

    var body: some View {
        Menu("Choose a Saved Pattern") {
            if !module.candidates.isEmpty {
                Section("Found in This Folder") {
                    ForEach(module.candidates, id: \.text) { candidate in
                        Button {
                            Task { await model.useFoundPattern(candidate.text, for: module.id) }
                        } label: {
                            current(candidate.text, module.templateText == candidate.text)
                        }
                    }
                }
            }
            let saved = model.savedPatternChoices(for: module.id)
            if !saved.isEmpty {
                Section("Saved") {
                    ForEach(saved) { choice in
                        Button {
                            Task { await model.useSavedPattern(choice.id, for: module.id) }
                        } label: {
                            current(choice.pattern.name, choice.isCurrent)
                        }
                        .disabled(choice.problem != nil)
                    }
                }
            }
            Section { saving }
        }
        .alert(String(localized: "Save Pattern"), isPresented: $isNaming) {
            TextField(String(localized: "Name"), text: $name)
            Button("Save") {
                let text = name.trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { _ = model.savePattern(of: module.id, as: text) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The pattern is kept under this name, to pick in other folders.")
        }
    }

    @ViewBuilder private var saving: some View {
        if let changed = model.savedPatternToUpdate(for: module.id) {
            Button("Update “\(changed.name)”") {
                Task { await model.updateSavedPattern(for: module.id) }
            }
            Button("Save as New Pattern…", action: askName)
        } else {
            Button("Save Pattern…", action: askName)
        }
        Button("Edit Saved Patterns…", action: editSaved)
    }

    private func askName() {
        name = ""
        isNaming = true
    }

    /// A menu item, ticked when it is the pattern in force.
    @ViewBuilder private func current(_ title: String, _ isCurrent: Bool) -> some View {
        if isCurrent {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
