import SwiftUI
import TreewiseCore
import TreewiseUI
import UniformTypeIdentifiers

/// Settings' Templates tab (ADR 0143), laid out as Saved Patterns is: the templates by name,
/// each with its root and how many folders it makes; a swipe duplicates or deletes one, ⋯
/// imports a file, and a tap opens its tree. A template is saved from a folder, so there is
/// no + for an empty one.
struct TemplatesSettings: View {
    let model: FolderTemplatesModel
    let undoManager: UndoManager
    @State private var isImporting = false
    /// A template the file holds that is here already, for Replace or Keep Both (ADR 0141).
    @State private var sameTemplate: (here: FolderTemplate, file: FolderTemplate)?
    @State private var isShowingProblem = false

    var body: some View {
        List {
            ForEach(model.templates) { template in
                NavigationLink {
                    TemplateEditor(model: model, id: template.id, undoManager: undoManager)
                } label: {
                    row(template)
                }
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        Task { await model.delete(template.id, undoManager: undoManager) }
                    }
                    Button("Duplicate") {
                        Task { await model.duplicate(template.id, undoManager: undoManager) }
                    }
                }
            }
        }
        .overlay {
            if model.templates.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Templates"), systemImage: "folder.badge.gearshape",
                    description: Text(
                        "Save a folder’s structure as a template from the folder’s menu."))
            }
        }
        .navigationTitle(Text("Templates"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Import…", systemImage: "square.and.arrow.down") { isImporting = true }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("templatesMore")
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            Task { await importTemplate(from: url) }
        }
        .confirmationDialog(
            sameTemplate.map { String(localized: "“\($0.here.name)” is here already") } ?? "",
            isPresented: Binding(
                get: { sameTemplate != nil }, set: { if !$0 { sameTemplate = nil } }),
            titleVisibility: .visible, presenting: sameTemplate
        ) { found in
            Button("Replace") {
                Task { await model.replace(withImported: found.file, undoManager: undoManager) }
            }
            Button("Keep Both") { Task { await model.keepBoth(found.file) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Replace it with the version in the file, or keep both?")
        }
        .alert(String(localized: "The file is no template"), isPresented: $isShowingProblem) {
            Button("OK", role: .cancel) {}
        }
        .task { await model.load() }
    }

    private func row(_ template: FolderTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
            Text(
                "\(template.root.name) · \(TemplateTreeRows.rows(of: template.root).count - 1) folders"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// Reads the file the user picked, which lies outside the app's own folders.
    private func importTemplate(from url: URL) async {
        let reachable = url.startAccessingSecurityScopedResource()
        defer { if reachable { url.stopAccessingSecurityScopedResource() } }
        let data = await Task.detached { (try? Data(contentsOf: url)) ?? Data() }.value
        switch await model.importTemplate(from: data) {
        case .imported: break
        case .sameTemplate(let here, let file): sameTemplate = (here, file)
        case .refused: isShowingProblem = true
        }
    }
}

/// A template's tree as rows, each folder with its path below the root and its depth, the
/// root first, as the editor and the list's count show it.
enum TemplateTreeRows {
    struct Row: Hashable {
        let path: [String]
        let tree: FolderTree
        var depth: Int { path.count }
    }

    static func rows(of root: FolderTree) -> [Row] {
        var rows: [Row] = []
        func add(_ tree: FolderTree, at path: [String]) {
            rows.append(Row(path: path, tree: tree))
            for folder in tree.folders { add(folder, at: path + [folder.name]) }
        }
        add(root, at: [])
        return rows
    }
}
