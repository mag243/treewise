import Foundation
import TreewiseCore
import os

/// Keeps this device's settings in sync through the `.treewise` folder of each cloud drive
/// that takes part, part by part (ADR 0144). The stores tell it what the user changed, from
/// what to what; `refresh()` reads every device's files and returns what the stores must
/// take over. A folder's settings merge per drive; the saved patterns and the templates
/// across all drives, and are written to each.
public actor SettingsSync {
    /// A change from another device, whole, for a store to take over without recording it.
    public enum Change: Hashable, Sendable {
        /// The settings of the folder at `path`, nil when they were removed.
        case folder(path: String, settings: FolderSettings?)
        /// The saved patterns, as their parts make them.
        case savedPatterns(SavedPatterns)
        /// A template, nil when it was removed.
        case template(id: String, template: FolderTemplate?)
    }

    /// What a refresh brought: the changes to take over, and this device's changes that
    /// another device's replaced without seeing them, for the safety net.
    public struct Refreshed: Sendable {
        public let changes: [Change]
        public let lost: [SyncBook.Conflict]
    }

    private static let logger = Logger(subsystem: LogSubsystem.name, category: "Sync")
    private static let queue = DispatchQueue(label: "me.m-domain.treewise.sync", qos: .utility)

    private let device: SyncDevice
    private let now: @Sendable () -> Date
    /// Which sync folder this device makes in a drive that has none.
    private let making: @Sendable (URL) -> SyncFolder.Making
    /// Why this device does not sync in a drive, by the drive's path.
    public private(set) var driveProblems: [String: SyncFolder.Problem] = [:]
    /// The drives that use the visible sync folder an iPad made, by their paths.
    public private(set) var visibleDrives: Set<String> = []
    private var drives: [URL] = []
    private var folderBooks: [String: SyncBook] = [:]
    private var shared: SyncBook
    private var written: [String: Set<SyncRecord>] = [:]
    /// The name of each device whose file was read, by its id.
    public private(set) var deviceNames: [String: String] = [:]

    /// A sync of `device`, its times from `now`, making in a drive without a sync folder the
    /// one `making` says: a Mac the hidden one, an iPad none until asked (ADR 0144).
    public init(
        device: SyncDevice, now: @escaping @Sendable () -> Date = Date.init,
        making: @escaping @Sendable (URL) -> SyncFolder.Making = { _ in .hidden }
    ) {
        self.device = device
        self.now = now
        self.making = making
        shared = SyncBook(device: device.id)
    }

    /// The roots of the drives that take part.
    public func setDrives(_ roots: [URL]) {
        drives = roots.map(\.standardizedFileURL)
        for root in drives where folderBooks[root.path] == nil {
            folderBooks[root.path] = SyncBook(device: device.id)
        }
    }

    /// The user changed the settings of the folder at `path` from `before` to `after`, nil
    /// for none; nothing for a folder outside the drives.
    public func folderChanged(
        at path: String, from before: FolderSettings?, to after: FolderSettings?
    ) async {
        guard let (root, relative) = place(of: path) else { return }
        let changes = SyncParts.changes(
            of: .folder(relative), from: before?.syncParts, to: after?.syncParts)
        guard !changes.isEmpty else { return }
        folderBooks[root]?.record(changes, now: now())
        await write(root)
    }

    /// Treewise moved the folder at `old` to `new`: its settings and those of the folders
    /// in it follow, also into another drive; out of the drives they are removed.
    public func folderMoved(from old: String, to new: String) async {
        guard let (oldRoot, oldPath) = place(of: old) else { return }
        let target = place(of: new)
        if let (newRoot, newPath) = target, newRoot == oldRoot {
            folderBooks[oldRoot]?.move(folder: oldPath, to: newPath, now: now())
            await write(oldRoot)
            return
        }
        let moving = SyncMove.records(
            movingFolder: oldPath, to: "", known: folderBooks[oldRoot]?.merged ?? [:], at: now(),
            device: device.id)
        let removals = moving.filter(\.isRemoval).map { ($0.key, $0.value) }
        folderBooks[oldRoot]?.record(Dictionary(removals, uniquingKeysWith: { $1 }), now: now())
        if let (newRoot, newPath) = target {
            folderBooks[newRoot]?.record(Self.arriving(moving, at: newPath), now: now())
            await write(newRoot)
        }
        await write(oldRoot)
    }

    /// The user changed the saved patterns from `before` to `after`.
    /// When the records hold no pattern yet, as after starting with the examples, the whole
    /// list is recorded.
    public func patternsChanged(from before: SavedPatterns?, to after: SavedPatterns) async {
        let recorded = shared.merged.keys.contains { $0.element.isPattern }
        let base = recorded ? before?.syncElements ?? [:] : [:]
        await recordShared(SyncParts.changes(from: base, to: after.syncElements))
    }

    /// The user changed the template `id` from `before` to `after`, nil for none; both carry
    /// their folders' ids. A removed template records only that it is gone.
    public func templateChanged(
        id: String, from before: FolderTemplate?, to after: FolderTemplate?
    ) async {
        guard let after else {
            await recordShared(before == nil ? [:] : [.exists(.template(id)): .bool(false)])
            return
        }
        await recordShared(
            SyncParts.changes(from: before?.syncElements ?? [:], to: after.syncElements))
    }

    private func recordShared(_ changes: [SyncKey: JSONValue]) async {
        guard !changes.isEmpty else { return }
        shared.record(changes, now: now())
        for root in drives { await write(root.path) }
    }

    /// Records the device's settings from before syncing, for elements no device's file
    /// knows; a saved pattern of the same name and text as one known is left out. Call after
    /// a first `refresh()`, so what the files hold is known.
    public func seed(
        folders: [String: FolderSettings], patterns: SavedPatterns?, templates: [FolderTemplate]
    ) async {
        for (path, settings) in folders {
            guard let (root, relative) = place(of: path) else { continue }
            folderBooks[root]?.seed(
                SyncParts.changes(of: .folder(relative), from: nil, to: settings.syncParts))
        }
        var elements: [SyncElement: [String: JSONValue]] = [:]
        for template in templates { elements.merge(template.syncElements) { $1 } }
        if let patterns {
            let known = Set(knownPatterns().map { [$0.name, $0.text] })
            let fresh = patterns.patterns.filter { !known.contains([$0.name, $0.text]) }
            for (element, parts) in patterns.syncElements {
                if case .pattern(let id) = element, !fresh.contains(where: { $0.id == id }) {
                    continue
                }
                elements[element] = parts
            }
        }
        shared.seed(SyncParts.changes(from: [:], to: elements))
        for root in drives { await write(root.path) }
    }

    /// The saved patterns the records hold.
    private func knownPatterns() -> [SavedPattern] {
        let values = Self.elements(of: shared.merged).filter {
            if case .pattern = $0.key { return true }
            return false
        }.compactMapValues(SyncParts.values)
        return values.isEmpty ? [] : SavedPatterns(syncElements: values).patterns
    }

    /// Reads every drive's files and returns the other devices' changes that now hold and
    /// were not taken over yet; writes this device's file where its records changed.
    public func refresh() async -> Refreshed {
        let date = now()
        var sharedOthers: Set<SyncRecord> = []
        var sharedOwn: [SyncRecord] = []
        var changes: [Change] = []
        var lost: [SyncBook.Conflict] = []
        for root in drives {
            guard let files = await read(root), var book = folderBooks[root.path] else { continue }
            for file in files { deviceNames[file.device] = file.name }
            let own = files.filter { $0.device == device.id }.flatMap(\.records)
            let others = files.filter { $0.device != device.id }.flatMap(\.records)
            sharedOwn += own.filter { !$0.key.element.isFolder }
            sharedOthers.formUnion(others.filter { !$0.key.element.isFolder })
            let absorbed = book.absorb(
                others: others.filter(\.key.element.isFolder),
                ownInFile: own.filter(\.key.element.isFolder), now: date)
            folderBooks[root.path] = book
            lost += absorbed.lost
            changes += Self.folderChanges(absorbed.taken, in: book, root: root.path)
        }
        let absorbed = shared.absorb(others: Array(sharedOthers), ownInFile: sharedOwn, now: date)
        lost += absorbed.lost
        changes += sharedChanges(absorbed.taken)
        for root in drives { await write(root.path) }
        return Refreshed(changes: changes, lost: lost)
    }

    /// Records `record`'s value again, as the user's change now: Restore in the safety net.
    /// Returns the element it changed, whole, for the stores and the app to take over.
    public func restore(_ record: SyncRecord) async -> [Change] {
        guard record.key.element.isFolder else {
            shared.record([record.key: record.value], now: now())
            for root in drives { await write(root.path) }
            return sharedChanges([record])
        }
        for (root, var book) in folderBooks where book.merged[record.key] != nil {
            book.record([record.key: record.value], now: now())
            folderBooks[root] = book
            await write(root)
            return Self.folderChanges([record], in: book, root: root)
        }
        return []
    }

    /// Hide Folder: hides the visible sync folder of the drive at `root` (ADR 0144).
    public func hideFolder(in root: URL) async throws {
        let folder = SyncFolder(driveRoot: root, device: device, making: making(root))
        _ = try await Self.run { try folder.hideFolder() }
        visibleDrives.remove(root.standardizedFileURL.path)
    }

    private func read(_ root: URL) async -> [DeviceSyncFile]? {
        let folder = SyncFolder(driveRoot: root, device: device, making: making(root))
        do {
            let (files, isVisible) = try await Self.run {
                (try folder.read().files, folder.usesVisibleFolder())
            }
            if isVisible {
                visibleDrives.insert(root.path)
            } else {
                visibleDrives.remove(root.path)
            }
            return files
        } catch {
            Self.logger.error("Sync files unreadable: \(error.localizedDescription)")
            return nil
        }
    }

    private static func folderChanges(_ taken: [SyncRecord], in book: SyncBook, root: String)
        -> [Change]
    {
        Set(taken.map(\.key.element)).sorted { $0.order < $1.order }.compactMap { element in
            guard case .folder(let path) = element else { return nil }
            let settings = SyncParts.values(of: book.parts(of: element))
                .flatMap(FolderSettings.init(syncParts:))
            return .folder(path: root + "/" + path, settings: settings)
        }
    }

    private func sharedChanges(_ taken: [SyncRecord]) -> [Change] {
        var changes: [Change] = []
        let elements = Set(taken.map(\.key.element))
        let all = Self.elements(of: shared.merged)
        if elements.contains(where: \.isPattern) {
            let patterns = all.filter(\.key.isPattern).compactMapValues(SyncParts.values)
            changes.append(.savedPatterns(SavedPatterns(syncElements: patterns)))
        }
        for id in Set(elements.compactMap(\.templateID)).sorted() {
            let records = all.filter { $0.key.templateID == id }
            changes.append(
                .template(id: id, template: FolderTemplate(syncID: id, records: records)))
        }
        return changes
    }

    /// The drive holding `path`, and the path from its root.
    private func place(of path: String) -> (root: String, path: String)? {
        for root in drives {
            if let relative = SyncFolder.path(of: path, inDriveAt: root.path), !relative.isEmpty {
                return (root.path, relative)
            }
        }
        return nil
    }

    /// Writes this device's file in the drive at `root` when its records changed.
    private func write(_ root: String) async {
        let records = Set(
            (folderBooks[root]?.own.values.map { $0 } ?? []) + shared.own.values.map { $0 })
        guard written[root] != records else { return }
        let url = URL(filePath: root)
        let folder = SyncFolder(driveRoot: url, device: device, making: making(url))
        let sorted = records.sorted { $0.key.order < $1.key.order }
        do {
            try await Self.run { try folder.write(sorted) }
            written[root] = records
            driveProblems[root] = nil
        } catch let problem as SyncFolder.Problem {
            driveProblems[root] = problem
        } catch {
            Self.logger.error("Sync file not written: \(error.localizedDescription)")
        }
    }

}

extension SettingsSync {
    /// The parts of folders moved out of another drive, at their paths under `newPath`.
    fileprivate static func arriving(_ moving: [SyncRecord], at newPath: String)
        -> [SyncKey: JSONValue]
    {
        var parts: [SyncKey: JSONValue] = [:]
        for record in moving where !record.isRemoval {
            guard case .folder(let path) = record.key.element else { continue }
            parts[SyncKey(.folder(newPath + path), record.key.part)] = record.value
        }
        return parts
    }

    fileprivate static func elements(of merged: [SyncKey: SyncRecord])
        -> [SyncElement: [String: SyncRecord]]
    {
        var elements: [SyncElement: [String: SyncRecord]] = [:]
        for (key, record) in merged { elements[key.element, default: [:]][key.part] = record }
        return elements
    }

    fileprivate static func run<Value: Sendable>(
        _ body: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try body() }) }
        }
    }
}

extension SyncElement {
    /// Whether the element is a folder's, merged per drive.
    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }

    var isPattern: Bool {
        switch self {
        case .pattern, .patternList: true
        default: false
        }
    }

    var templateID: String? {
        switch self {
        case .template(let id), .templateFolder(let id, _): id
        default: nil
        }
    }

    var order: String { SyncKey(self, "").order }
}

extension SettingsSync {
    /// Records what the user changed in a folder's settings.
    public func handle(_ notice: FolderSettingsNotice) async {
        switch notice {
        case .changed(let path, let before, let after):
            await folderChanged(at: path, from: before, to: after)
        case .moved(let old, let new): await folderMoved(from: old, to: new)
        }
    }
}
