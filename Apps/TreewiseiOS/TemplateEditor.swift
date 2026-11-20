import SwiftUI
import TreewiseCore
import TreewiseUI
import UniformTypeIdentifiers

/// One template in Settings' Templates tab (ADR 0143): its name, and its tree with each
/// folder at its depth. A tap renames a folder, with Insert Field; its swipe and menu make a
/// folder inside, move it into another, take its name settings off (ADR 0101) and delete it.
/// Every change is saved at once, with Undo; ⋯ exports the template.
struct TemplateEditor: View {
    let model: FolderTemplatesModel
    let id: String
    let undoManager: UndoManager
    @State private var name = ""
    @State private var renaming: TemplateTreeRows.Row?
    @State private var isExporting = false

    /// How far a folder is set in for each level below the root.
    private static let indent: CGFloat = 20

    private var template: FolderTemplate? { model.templates.first { $0.id == id } }

    var body: some View {
        List {
            Section {
                TextField(String(localized: "Name"), text: $name)
                    .onSubmit(renameTemplate)
                    .accessibilityIdentifier("templateName")
            }
            if let template {
                Section {
                    ForEach(TemplateTreeRows.rows(of: template.root), id: \.path) { row in
                        folder(row, in: template.root)
                    }
                } footer: {
                    Text(
                        "Tap a folder to rename it. Its menu makes a folder inside, moves or deletes it."
                    )
                }
            }
        }
        .navigationTitle(Text(template?.name ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Export…", systemImage: "square.and.arrow.up") { isExporting = true }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $renaming) { row in
            TemplateFolderNameSheet(row: row) { newName in
                Task {
                    await model.renameFolder(
                        row.path, of: id, to: newName, undoManager: undoManager)
                }
            }
        }
        .fileExporter(
            isPresented: $isExporting, document: template.flatMap(TemplateDocument.init),
            contentType: .json,
            defaultFilename: String(localized: "\(template?.name ?? "") Folder Template")
        ) { _ in }
        .onAppear { name = template?.name ?? "" }
        .onDisappear(perform: renameTemplate)
    }

    private func folder(_ row: TemplateTreeRows.Row, in root: FolderTree) -> some View {
        Button {
            renaming = row
        } label: {
            HStack {
                // A symbol and a text rather than a Label, whose symbol a list sets in a
                // column of its own, apart from the row's indent.
                Image(systemName: "folder").foregroundStyle(Color.accentColor)
                Text(row.tree.name).foregroundStyle(.primary)
            }
            .padding(.leading, CGFloat(row.depth) * Self.indent)
        }
        .contextMenu { menu(for: row, in: root) }
        .swipeActions {
            if !row.path.isEmpty {
                Button("Delete", role: .destructive) { remove(row) }
            }
            Button("New Folder Inside") { add(in: row) }
        }
    }

    @ViewBuilder
    private func menu(for row: TemplateTreeRows.Row, in root: FolderTree) -> some View {
        Button("New Folder Inside", systemImage: "folder.badge.plus") { add(in: row) }
        Button("Rename", systemImage: "pencil") { renaming = row }
        if !row.path.isEmpty {
            let targets = Self.targets(for: row, in: root)
            if !targets.isEmpty {
                Menu("Move Into", systemImage: "folder") {
                    ForEach(targets, id: \.path) { target in
                        Button(
                            target.path.isEmpty ? root.name : target.path.joined(separator: " › ")
                        ) {
                            move(row, into: target)
                        }
                    }
                }
            }
        }
        if row.tree.names != nil {
            Button("Remove Name Settings", systemImage: "textformat") {
                Task { await model.removeNames(at: row.path, of: id, undoManager: undoManager) }
            }
        }
        if !row.path.isEmpty {
            Button("Delete", systemImage: "trash", role: .destructive) { remove(row) }
        }
    }

    /// The folders `row` can move into: not itself, nothing inside it, nor where it is.
    private static func targets(for row: TemplateTreeRows.Row, in root: FolderTree)
        -> [TemplateTreeRows.Row]
    {
        TemplateTreeRows.rows(of: root).filter { target in
            !target.path.starts(with: row.path) && target.path != Array(row.path.dropLast())
        }
    }

    private func renameTemplate() {
        guard let template, name != template.name else { return }
        let newName = name
        Task { await model.rename(id, to: newName, undoManager: undoManager) }
    }

    private func add(in row: TemplateTreeRows.Row) {
        let name = String(localized: "untitled folder")
        Task { await model.addFolder(in: row.path, of: id, named: name, undoManager: undoManager) }
    }

    private func remove(_ row: TemplateTreeRows.Row) {
        Task { await model.removeFolder(row.path, of: id, undoManager: undoManager) }
    }

    private func move(_ row: TemplateTreeRows.Row, into target: TemplateTreeRows.Row) {
        Task {
            await model.moveFolder(row.path, into: target.path, of: id, undoManager: undoManager)
        }
    }
}

extension TemplateTreeRows.Row: Identifiable {
    var id: [String] { path }
}

/// A template's folder renamed, with Insert Field for the fields that folder takes
/// (ADR 0096, ADR 0100).
private struct TemplateFolderNameSheet: View {
    let row: TemplateTreeRows.Row
    let rename: (String) -> Void
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    private var choices: [TemplateFieldChoices.Choice] {
        TemplateFieldChoices.offered(atRoot: row.path.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                // The menu sits beside the name, as on the Mac: a menu as a form's row of its
                // own opens only from its text, not from the rest of the row.
                HStack {
                    TextField(String(localized: "Name"), text: $name)
                        .accessibilityIdentifier("templateFolderName")
                    Menu("Insert Field") {
                        ForEach(choices, id: \.field) { choice in
                            Button(choice.title) {
                                name = TemplateFieldChoices.name(name, adding: choice.field)
                            }
                        }
                    }
                    .fixedSize()
                    .buttonStyle(.borderless)
                }
            }
            .navigationTitle(Text("Rename Folder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if name != row.tree.name { rename(name) }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { name = row.tree.name }
        .presentationDetents([.medium])
    }
}

/// A template's file for Export… (ADR 0141): JSON with its id.
struct TemplateDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init?(_ template: FolderTemplate) {
        guard let data = try? FolderTemplateFile.data(of: template) else { return nil }
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
