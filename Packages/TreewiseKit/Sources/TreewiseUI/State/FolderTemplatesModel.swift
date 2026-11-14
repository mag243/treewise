import Foundation
import Observation
import TreewiseCore

/// The saved folder structure templates, as Settings' Templates tab shows and edits them
/// (ADR 0091, ADR 0095): each change is saved at once, and Undo takes it back.
@MainActor
@Observable
public final class FolderTemplatesModel {
    /// Why a change was not taken.
    public enum Problem: Hashable, Sendable {
        /// A template's name is empty.
        case emptyName
        /// Another template has the name.
        case nameTaken(String)
        /// The tree cannot take the change.
        case tree(FolderTree.Problem)
        /// A file is no template.
        case file(FolderTemplateFile.Problem)
        /// Saving or deleting failed.
        case notSaved
    }

    /// A change of what is kept, which can be undone by another.
    private enum Change {
        case save(FolderTemplate)
        case delete(id: String)
        case restore(TrashedItem, id: String)
    }

    /// The templates, ordered by name.
    public private(set) var templates: [FolderTemplate] = []
    /// Why the last change was not taken, until the next one is.
    public private(set) var problem: Problem?

    private let store: any FolderTemplateStoring

    /// A model of the templates in `store`.
    public init(store: any FolderTemplateStoring) {
        self.store = store
    }

    /// Reads the templates.
    public func load() async {
        templates = await store.templates()
    }

    /// The template with this name, if there is one.
    public func template(named name: String) -> FolderTemplate? {
        templates.first { $0.name == name }
    }

    /// Renames a template; an empty name, or one another template has, is not taken.
    public func rename(_ id: String, to name: String, undoManager: UndoManager?) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return refuse(.emptyName) }
        guard !templates.contains(where: { $0.id != id && $0.name == trimmed }) else {
            return refuse(.nameTaken(trimmed))
        }
        guard var template = templates.first(where: { $0.id == id }) else { return }
        template.name = trimmed
        await apply(.save(template), named: "Rename Template", undoManager: undoManager)
    }

    /// Deletes a template at once; Undo brings it back.
    public func delete(_ id: String, undoManager: UndoManager?) async {
        await apply(.delete(id: id), named: "Delete Template", undoManager: undoManager)
    }

    /// Saves `tree` as the template named `name`: in place of the one of that name, keeping
    /// its id, or as a new one.
    public func save(_ tree: FolderTree, as name: String) async {
        let template = FolderTemplate(
            id: template(named: name)?.id ?? UUID().uuidString, name: name, root: tree)
        await apply(.save(template), named: "Save Template", undoManager: nil)
    }

    /// Reads a template's file as a new template.
    public func importTemplate(from data: Data) async {
        do {
            _ = try await store.importTemplate(from: data)
            problem = nil
        } catch {
            problem = .file(error)
        }
        await load()
    }

    // MARK: Editing a tree (ADR 0095)

    /// Adds a folder named `name`, numbered when taken, in the folder at `path`, and returns
    /// the path of the folder added.
    @discardableResult
    public func addFolder(
        in path: [String], of id: String, named name: String, undoManager: UndoManager?
    ) async -> [String]? {
        await edit(id, named: "New Folder", undoManager: undoManager) {
            try $0.adding(in: path, named: name)
        }
    }

    /// Renames the folder at `path`, and returns its new path.
    @discardableResult
    public func renameFolder(
        _ path: [String], of id: String, to name: String, undoManager: UndoManager?
    ) async -> [String]? {
        await edit(id, named: "Rename", undoManager: undoManager) {
            try $0.renaming(path, to: name)
        }
    }

    /// Removes the folder at `path` with everything below it.
    public func removeFolder(_ path: [String], of id: String, undoManager: UndoManager?) async {
        await edit(id, named: "Delete", undoManager: undoManager) { tree in
            (tree.removing(path), Array(path.dropLast()))
        }
    }

    /// Removes the name settings the folder at `path` gives the folders made from it
    /// (ADR 0101).
    public func removeNames(at path: [String], of id: String, undoManager: UndoManager?) async {
        await edit(id, named: "Remove Name Settings", undoManager: undoManager) { tree in
            (tree.removingNames(at: path), path)
        }
    }

    /// Moves the folder at `path` into the one at `target`, and returns its new path.
    @discardableResult
    public func moveFolder(
        _ path: [String], into target: [String], of id: String, undoManager: UndoManager?
    ) async -> [String]? {
        await edit(id, named: "Move", undoManager: undoManager) {
            try $0.moving(path, into: target)
        }
    }

    @discardableResult
    private func edit(
        _ id: String, named name: String.LocalizationValue, undoManager: UndoManager?,
        _ change: (FolderTree) throws -> (tree: FolderTree, path: [String])
    ) async -> [String]? {
        guard var template = templates.first(where: { $0.id == id }) else { return nil }
        do {
            let (tree, path) = try change(template.root)
            template.root = tree
            await apply(.save(template), named: name, undoManager: undoManager)
            return path
        } catch {
            refuse((error as? FolderTree.Problem).map(Problem.tree) ?? .notSaved)
            return nil
        }
    }

    // MARK: Changes and Undo

    private func refuse(_ found: Problem) {
        problem = found
    }

    private func apply(
        _ change: Change, named name: String.LocalizationValue, undoManager: UndoManager?
    ) async {
        guard let inverse = await perform(change) else { return }
        problem = nil
        register(Task { inverse }, named: String(localized: name, bundle: .module), undoManager)
    }

    /// Registers the change that undoes the last one. It registers its own inverse at once,
    /// while Undo runs, so that it lands on the redo stack, and performs it as the task
    /// before it ends (as `BrowserState` does).
    private func register(
        _ inverse: Task<Change?, Never>, named name: String, _ undoManager: UndoManager?
    ) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { model in
            let redo = Task { @MainActor () -> Change? in
                guard let change = await inverse.value else { return nil }
                return await model.perform(change)
            }
            model.register(redo, named: name, undoManager)
        }
        undoManager.setActionName(name)
    }

    /// Performs a change and returns the one that undoes it, or nil when it failed.
    private func perform(_ change: Change) async -> Change? {
        do {
            let inverse: Change
            switch change {
            case .save(let template):
                let before = templates.first { $0.id == template.id }
                try await store.save(template)
                inverse = before.map(Change.save) ?? .delete(id: template.id)
            case .delete(let id):
                inverse = .restore(try await store.delete(id: id), id: id)
            case .restore(let trashed, let id):
                try await store.restore(trashed)
                inverse = .delete(id: id)
            }
            await load()
            return inverse
        } catch {
            problem = .notSaved
            return nil
        }
    }
}
