import Foundation
import Synchronization
import TreewiseCore

/// An in-memory file system whose tree can change while a view model reads
/// it: by a test playing external changes, or through `FileOperating`, with an
/// in-memory Trash (ADR 0018). Moved items keep their identity; copies, new
/// folders and trashed items get new ones.
public final class ChangingFileSystem: FileOperating {
    private struct State {
        var tree: InMemoryFileSystem
        var trash: [FileItem.ID: [FileItem]] = [:]
        var nextNumber = 1
        var failure: (any Error)?
        var isHeld = false

        mutating func newID(_ prefix: String) -> FileItem.ID {
            defer { nextNumber += 1 }
            return FileItem.ID("\(prefix)-\(nextNumber)")
        }
    }

    private let state: Mutex<State>

    /// Creates a file system that starts as `tree`.
    public init(_ tree: InMemoryFileSystem = Fixture.standard) {
        state = Mutex(State(tree: tree))
    }

    /// Removes an item and everything inside it, as another app would.
    public func remove(_ id: FileItem.ID) {
        state.withLock { $0.tree = $0.tree.removing(id) }
    }

    /// Adds an item, as another app would.
    ///
    /// Precondition: its parent exists and its identity is new.
    public func add(_ item: FileItem) {
        state.withLock { $0.tree = $0.tree.adding(item) }
    }

    /// Makes every later change throw `error`, as a full disk or a vanished
    /// volume would; `nil` lets changes succeed again.
    public func failChanges(with error: (any Error)?) {
        state.withLock { $0.failure = error }
    }

    /// Makes every later copy and move wait until `releaseChanges()`, so a
    /// test can act while an operation runs. A change cancelled by then
    /// throws `FileSystemError.cancelled`, as the disk's runner does.
    public func holdChanges() {
        state.withLock { $0.isHeld = true }
    }

    /// Lets held changes go on.
    public func releaseChanges() {
        state.withLock { $0.isHeld = false }
    }

    /// The files of an item, itself included when it is one.
    private func files(of item: FileItem) -> [FileItem] {
        state.withLock { $0.tree.subtree(item.id) }.filter { !$0.isContainer }
    }

    /// Reports each file as a copy does, before copying it.
    private func report(_ files: [FileItem], to onFile: FileCopyProgress) {
        var copied: Int64 = 0
        for file in files {
            onFile(file.name, copied)
            copied += file.size ?? 0
        }
    }

    private func waitWhileHeld() async throws {
        while state.withLock({ $0.isHeld }) { await Task.yield() }
        if Task.isCancelled { throw FileSystemError.cancelled }
    }

    /// The items in the Trash, by their identity there.
    public var trashedIDs: Set<FileItem.ID> {
        state.withLock { Set($0.trash.keys) }
    }

    public func contents(of folder: FileItem.ID) async throws -> [FileItem] {
        try await tree().contents(of: folder)
    }

    public func item(at id: FileItem.ID) async throws -> FileItem {
        try await tree().item(at: id)
    }

    public func locations() async throws -> [FileItem] {
        try await tree().locations()
    }

    public func favorites() async throws -> [FileItem] {
        try await tree().favorites()
    }

    public func availableCapacity(of folder: FileItem.ID) async throws -> Int64? {
        try await tree().availableCapacity(of: folder)
    }

    public func itemsByName(in folder: FileItem.ID) async throws -> [String: FileItem] {
        Dictionary(try await contents(of: folder).map { ($0.name, $0) }) { first, _ in first }
    }

    public func byteCount(of item: FileItem) async throws -> Int64 {
        files(of: item).compactMap(\.size).reduce(0, +)
    }

    public func copy(
        _ item: FileItem, into folder: FileItem.ID, as name: String,
        onFile: @escaping FileCopyProgress, control: TransferControl
    ) async throws -> FileItem {
        try await waitWhileHeld()
        guard await control.untilResumed() else { throw FileSystemError.cancelled }
        report(files(of: item), to: onFile)
        return try state.withLock { state in
            if let failure = state.failure { throw failure }
            let target = try Self.existing(folder, in: state.tree)
            var newIDs: [FileItem.ID: FileItem.ID] = [:]
            let copies = state.tree.subtree(item.id).map { original -> FileItem in
                let id = state.newID("copy")
                newIDs[original.id] = id
                var copy = FileItem(
                    id: id, name: original.name, kind: original.kind,
                    parentID: original.parentID.flatMap { newIDs[$0] }, volume: target.volume,
                    modified: original.modified, size: original.size,
                    kindDescription: original.kindDescription)
                if original.id == item.id {
                    copy.parentID = folder
                    copy.name = name
                }
                return copy
            }
            guard let root = copies.first else { throw FileSystemError.notFound(item.id) }
            state.tree = copies.reduce(state.tree) { $0.adding($1) }
            return root
        }
    }

    public func move(
        _ item: FileItem, into folder: FileItem.ID, as name: String,
        onFile: @escaping FileCopyProgress, control: TransferControl
    ) async throws -> FileItem {
        try await waitWhileHeld()
        guard await control.untilResumed() else { throw FileSystemError.cancelled }
        if try await self.item(at: folder).volume != item.volume {
            report(files(of: item), to: onFile)
        }
        return try state.withLock { state in
            if let failure = state.failure { throw failure }
            let target = try Self.existing(folder, in: state.tree)
            let moved = state.tree.subtree(item.id).map { original -> FileItem in
                var changed = original
                changed.volume = target.volume
                if original.id == item.id {
                    changed.parentID = folder
                    changed.name = name
                }
                return changed
            }
            guard let root = moved.first else { throw FileSystemError.notFound(item.id) }
            state.tree = state.tree.replacing(moved)
            return root
        }
    }

    public func trash(_ id: FileItem.ID) async throws -> TrashedItem {
        try state.withLock { state in
            if let failure = state.failure { throw failure }
            let subtree = state.tree.subtree(id)
            guard !subtree.isEmpty else { throw FileSystemError.notFound(id) }
            let trashID = state.newID("trash")
            state.trash[trashID] = subtree
            state.tree = state.tree.removing(id)
            return TrashedItem(trashID: trashID, originalID: id)
        }
    }

    public func restore(_ trashed: TrashedItem) async throws -> FileItem {
        try state.withLock { state in
            if let failure = state.failure { throw failure }
            guard let subtree = state.trash.removeValue(forKey: trashed.trashID),
                let root = subtree.first
            else {
                throw FileSystemError.notFound(trashed.trashID)
            }
            state.tree = subtree.reduce(state.tree) { $0.adding($1) }
            return root
        }
    }

    public func createFolder(in folder: FileItem.ID, named name: String) async throws -> FileItem {
        try state.withLock { state in
            if let failure = state.failure { throw failure }
            let parent = try Self.existing(folder, in: state.tree)
            let created = FileItem(
                id: state.newID("folder"), name: name, kind: .folder, parentID: folder,
                volume: parent.volume)
            state.tree = state.tree.adding(created)
            return created
        }
    }

    private func tree() -> InMemoryFileSystem {
        state.withLock { $0.tree }
    }

    private static func existing(_ id: FileItem.ID, in tree: InMemoryFileSystem) throws -> FileItem
    {
        guard let item = tree[id] else { throw FileSystemError.notFound(id) }
        return item
    }
}
