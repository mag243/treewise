import Foundation
import TreewiseCore

/// What the window does to change an archive it shows (ADR 0078). An action
/// is one change to the archive, however many items it holds.
extension BrowserState {
    /// Copies or moves items into a folder of an archive, asking about names
    /// that are taken.
    ///
    /// - Returns: whether the items landed.
    func transferIntoArchive(
        _ items: [FileItem], to folder: FileItem.ID, mode: TransferMode,
        resolver: any ConflictResolving, undoManager: UndoManager?
    ) async -> Bool {
        guard let place = ArchivePath(folder), let operations, let archives else { return false }
        let result = await runArchiveWork(
            name: Self.actionName(mode == .move ? "Move" : "Copy"), undoManager: undoManager
        ) { reporter, control in
            let names = try await operations.itemsByName(in: folder)
            let landing = await Self.landing(
                items, in: folder, among: names, mode: mode, resolver: resolver)
            guard !landing.isEmpty || items.isEmpty else {
                return OperationResult(items: [], undo: .none, stopped: true)
            }
            let edit = try await Self.edit(landing, in: place, mode: mode, archives: archives)
            let undo = try await archives.apply(
                edit, to: place.archive, onProgress: reporter, control: control)
            let produced = landing.map { Self.entry(at: place.child($1), kind: $0.kind) }
            return OperationResult(items: produced, undo: undo)
        }
        guard let result, !result.stopped else { return false }
        if layout.focusedPane.activeTab.folder == folder { selectInFocusedTab(result.items) }
        return true
    }

    /// Renames an entry of the archive the item is in.
    func renameInArchive(
        _ item: FileItem, at place: ArchivePath, to name: String, undoManager: UndoManager?
    )
        async
    {
        guard FolderNaming.isValidName(name) else {
            failure = .invalidName(name)
            return
        }
        let target = place.sibling(named: name)
        let result = await changeArchive(
            place.archive, name: Self.actionName("Rename"), undoManager: undoManager,
            edit: .relocate(from: place.entry, to: target.entry),
            produces: Self.entry(at: target, kind: item.kind))
        selectInFocusedTab(result?.items ?? [])
    }

    /// Makes a new folder in the folder of an archive that the focused pane shows.
    func newFolderInArchive(at place: ArchivePath, undoManager: UndoManager?, locale: Locale) async
        -> FileItem?
    {
        guard let operations else { return nil }
        let names = (try? await operations.itemsByName(in: place.id).keys).map(Array.init) ?? []
        let target = place.child(FolderNaming.newFolderName(among: names, locale: locale))
        let result = await changeArchive(
            place.archive, name: Self.actionName("New Folder"), undoManager: undoManager,
            edit: .newFolder(target.entry), produces: Self.entry(at: target, kind: .folder))
        selectInFocusedTab(result?.items ?? [])
        renameRequest = result?.items.first?.id
        return result?.items.first
    }

    /// Removes entries from the archive they are in, which undo brings back.
    func removeFromArchive(_ places: [ArchivePath], undoManager: UndoManager?) async -> Bool {
        guard let archive = places.first?.archive else { return false }
        let result = await changeArchive(
            archive, name: Self.actionName("Move to Trash"), undoManager: undoManager,
            edit: .remove(places.map(\.entry)), produces: nil)
        return result != nil
    }

    /// Changes an archive. What it produces is described from what is known,
    /// not read back: undo must be ready as soon as the new archive is in place.
    private func changeArchive(
        _ archive: FileItem.ID, name: String, undoManager: UndoManager?, edit: ArchiveEdit,
        produces item: FileItem?
    ) async -> OperationResult? {
        guard let archives else { return nil }
        return await runArchiveWork(name: name, undoManager: undoManager) { reporter, control in
            let undo = try await archives.apply(
                edit, to: archive, onProgress: reporter, control: control)
            return OperationResult(items: item.map { [$0] } ?? [], undo: undo)
        }
    }

    private nonisolated static func entry(at place: ArchivePath, kind: ItemKind) -> FileItem {
        FileItem(
            id: place.id, name: place.name, kind: kind, parentID: place.parent,
            volume: place.volume)
    }

    /// Where each item lands: its own name, or what the answer about a name
    /// that is taken makes of it. Empty when the user stopped.
    private static func landing(
        _ items: [FileItem], in folder: FileItem.ID, among names: [String: FileItem],
        mode: TransferMode, resolver: any ConflictResolving
    ) async -> [(FileItem, String)] {
        var taken = Array(names.keys)
        var result: [(FileItem, String)] = []
        for item in items {
            let key = ConflictResolver.comparisonKey(item.name)
            let clash = names.values.first { ConflictResolver.comparisonKey($0.name) == key }
            guard let clash else {
                result.append((item, item.name))
                taken.append(item.name)
                continue
            }
            let isInPlace = mode == .copy && item.parentID == folder
            switch isInPlace ? .keepBoth : await resolver.decide(existing: clash, incoming: item) {
            case .replace:
                result.append((item, clash.name))
            case .keepBoth:
                let name = ConflictResolver.availableName(
                    for: item.name, kind: item.kind, among: taken)
                result.append((item, name))
                taken.append(name)
            case .stop:
                return []
            }
        }
        return result
    }

    private static func edit(
        _ landing: [(FileItem, String)], in place: ArchivePath, mode: TransferMode,
        archives: any ArchiveOperating
    ) async throws -> ArchiveEdit {
        if mode == .move {
            let moves = landing.compactMap { item, name -> ArchiveRelocation? in
                ArchivePath(item.id).map {
                    ArchiveRelocation(from: $0.entry, to: place.child(name).entry)
                }
            }
            return .relocations(moves)
        }
        var additions: [ArchiveAddition] = []
        for (item, name) in landing {
            var source = item.id.diskURL
            if source == nil { source = try await archives.cachedCopy(of: item) }
            guard let source else { continue }
            additions.append(ArchiveAddition(source: source, path: place.child(name).entry))
        }
        return .add(additions)
    }
}
