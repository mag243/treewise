import Foundation

/// Called before each file of an item is copied and while it copies, with the
/// file's name and the bytes of the item copied so far (ADR 0021, ADR 0026).
public typealias FileCopyProgress = @Sendable (_ file: String, _ copiedBytes: Int64) -> Void

/// Changes files: moves, copies, renames, creates folders and uses the Trash
/// (ADR 0018). Every change returns the record that undoes it.
public protocol FileOperating: FileSystemProviding {
    /// Lists a folder's items by name, for conflict checks.
    func itemsByName(in folder: FileItem.ID) async throws -> [String: FileItem]
    /// The bytes an item holds: a file's size, or the sum of a folder's files.
    func byteCount(of item: FileItem) async throws -> Int64
    /// Copies an item into a folder under a name; the copy is complete or absent.
    /// `onFile` hears of every file as it copies; `control` pauses and stops it,
    /// a stop throwing `FileSystemError.cancelled`.
    func copy(
        _ item: FileItem, into folder: FileItem.ID, as name: String,
        onFile: @escaping FileCopyProgress, control: TransferControl
    ) async throws -> FileItem
    /// Moves an item into a folder under a name, which may rename it. A move to
    /// another volume copies, reporting to `onFile` and following `control`.
    func move(
        _ item: FileItem, into folder: FileItem.ID, as name: String,
        onFile: @escaping FileCopyProgress, control: TransferControl
    ) async throws -> FileItem
    /// Moves an item to the Trash.
    func trash(_ id: FileItem.ID) async throws -> TrashedItem
    /// Puts an item back from the Trash where it was.
    func restore(_ trashed: TrashedItem) async throws -> FileItem
    /// Creates an empty folder.
    func createFolder(in folder: FileItem.ID, named name: String) async throws -> FileItem
}

extension FileOperating {
    /// Copies an item into a folder under a name, without reporting its files.
    public func copy(_ item: FileItem, into folder: FileItem.ID, as name: String) async throws
        -> FileItem
    {
        try await copy(
            item, into: folder, as: name, onFile: { _, _ in }, control: TransferControl())
    }

    /// Moves an item into a folder under a name, without reporting its files.
    public func move(_ item: FileItem, into folder: FileItem.ID, as name: String) async throws
        -> FileItem
    {
        try await move(
            item, into: folder, as: name, onFile: { _, _ in }, control: TransferControl())
    }

    /// Moves or copies items into a folder (`TransferRunner`).
    @discardableResult
    public func transfer(
        _ items: [FileItem], to folder: FileItem.ID, mode: TransferMode,
        resolver: any ConflictResolving,
        progress: @escaping @Sendable (OperationProgress) -> Void = { _ in },
        control: TransferControl = TransferControl()
    ) async throws -> OperationResult {
        try await TransferRunner(
            operations: self, resolver: resolver, progress: progress, control: control
        )
        .run(items, to: folder, mode: mode)
    }

    /// Renames an item within its folder.
    ///
    /// - Throws: `invalidName` for a name `FolderNaming` rejects, `alreadyExists`
    ///   when another item has the name.
    @discardableResult
    public func rename(_ item: FileItem, to name: String) async throws -> OperationResult {
        guard FolderNaming.isValidName(name) else { throw FileSystemError.invalidName(name) }
        guard let folder = item.parentID else { throw FileSystemError.notWritable(item.id) }
        let key = ConflictResolver.comparisonKey(name)
        let taken = try await itemsByName(in: folder).values.contains {
            $0.id != item.id && ConflictResolver.comparisonKey($0.name) == key
        }
        guard !taken else { throw FileSystemError.alreadyExists(item.id) }
        let renamed = try await move(item, into: folder, as: name)
        return OperationResult(
            items: [renamed],
            undo: .relocate([Relocation(item: renamed.id, folder: folder, name: item.name)]))
    }

    /// Creates a folder named "untitled folder" (numbered when taken) in `folder`.
    @discardableResult
    public func createUntitledFolder(in folder: FileItem.ID, locale: Locale) async throws
        -> OperationResult
    {
        let name = FolderNaming.newFolderName(
            among: try await itemsByName(in: folder).keys, locale: locale)
        let created = try await createFolder(in: folder, named: name)
        return OperationResult(items: [created], undo: .trash([created.id]))
    }

    /// Moves items to the Trash.
    @discardableResult
    public func moveToTrash(_ ids: [FileItem.ID]) async throws -> OperationResult {
        var trashed: [TrashedItem] = []
        for id in ids {
            try Task.checkCancellation()
            trashed.append(try await trash(id))
        }
        return OperationResult(items: [], undo: .restore(trashed))
    }

    /// Performs an undo record, and returns the record that redoes it.
    @discardableResult
    public func undo(_ record: UndoRecord) async throws -> OperationResult {
        switch record {
        case .none:
            return OperationResult(items: [], undo: .none)
        case .relocate(let relocations):
            return try await relocate(relocations)
        case .trash(let ids):
            return try await moveToTrash(ids)
        case .restore(let trashed):
            var restored: [FileItem] = []
            for item in trashed { restored.append(try await restore(item)) }
            return OperationResult(items: restored, undo: .trash(restored.map(\.id)))
        case .sequence(let records):
            var items: [FileItem] = []
            var redo: [UndoRecord] = []
            for step in records {
                let result = try await undo(step)
                items += result.items
                redo.insert(result.undo, at: 0)
            }
            return OperationResult(items: items, undo: .sequence(redo))
        }
    }

    private func relocate(_ relocations: [Relocation]) async throws -> OperationResult {
        var moved: [FileItem] = []
        var back: [Relocation] = []
        for relocation in relocations {
            let item = try await item(at: relocation.item)
            guard let origin = item.parentID else { throw FileSystemError.notWritable(item.id) }
            let result = try await move(item, into: relocation.folder, as: relocation.name)
            moved.append(result)
            back.append(Relocation(item: result.id, folder: origin, name: item.name))
        }
        return OperationResult(items: moved, undo: .relocate(back))
    }
}
