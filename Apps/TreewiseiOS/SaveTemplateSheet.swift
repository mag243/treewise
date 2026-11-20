import SwiftUI
import TreewiseCore
import TreewiseUI

/// What a folder's Folder Structure ▸ asks for (ADR 0091): to save the folder's structure as
/// a template, or to make a template's folders in it.
enum FolderStructureRequest: Identifiable {
    case save(FileItem.ID)
    case make(FolderTemplate, in: FileItem.ID)

    var id: String {
        switch self {
        case .save(let folder): "save " + folder.rawValue
        case .make(let template, let folder): "make \(template.id) " + folder.rawValue
        }
    }
}

/// Save as Template… (ADR 0091, ADR 0099): the folder's tree read, its name proposed, and
/// what is saved shown before Save. A name another template has asks to replace it. Saved as
/// it is, its names as written, as the iPad has no add-on to write a year as `{year}`.
struct SaveTemplateSheet: View {
    let folder: FileItem.ID
    let browser: BrowserState
    @State private var name = ""
    @State private var tree: FolderTree?
    @State private var problem: String?
    @State private var isAskingToReplace = false
    @Environment(\.dismiss) private var dismiss

    /// How far a folder is set in for each level below the root.
    private static let indent: CGFloat = 20

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Name"), text: $name)
                        .accessibilityIdentifier("templateName")
                } footer: {
                    Text("The folders in it, at every depth. Files are not saved.")
                }
                if let tree {
                    Section {
                        ForEach(TemplateTreeRows.rows(of: tree), id: \.path) { row in
                            Label(row.tree.name, systemImage: "folder")
                                .padding(.leading, CGFloat(row.depth) * Self.indent)
                        }
                    }
                } else if let problem {
                    Section { Text(problem).foregroundStyle(.red) }
                }
            }
            .navigationTitle(Text("Save as Template"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: askToSave)
                        .disabled(tree == nil || trimmedName.isEmpty)
                }
            }
            .confirmationDialog(
                String(localized: "A template named “\(trimmedName)” already exists."),
                isPresented: $isAskingToReplace, titleVisibility: .visible
            ) {
                Button("Replace", role: .destructive, action: save)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Replace it with this folder’s structure?")
            }
        }
        .task { await read() }
    }

    private func read() async {
        guard let item = try? await browser.fileSystem.item(at: folder) else {
            problem = String(localized: "The folder’s structure could not be read.")
            return
        }
        name = FolderTemplatesModel.proposedName(for: item)
        do {
            let read = try await browser.fileSystem.folderTree(of: item)
            try read.checkTemplate()
            tree = read
        } catch let found as FolderTree.Problem {
            problem = TemplateProblemText.text(for: found)
        } catch {
            problem = String(localized: "The folder’s structure could not be read.")
        }
    }

    private func askToSave() {
        if NameServices.templateList.template(named: trimmedName) != nil {
            isAskingToReplace = true
        } else {
            save()
        }
    }

    private func save() {
        guard let tree else { return }
        let name = trimmedName
        Task { await NameServices.templateList.save(tree, as: name) }
        dismiss()
    }
}
