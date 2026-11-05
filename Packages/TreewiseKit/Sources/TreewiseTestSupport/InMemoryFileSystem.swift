import TreewiseCore

/// A fixed tree of items held in memory, for view-model tests and previews.
/// This Mac (ADR 0044) lists the locations; a volume may name it as its parent.
///
/// Invariant: every `parentID` refers to an item in the tree, or to This Mac.
public struct InMemoryFileSystem: FileSystemProviding {
    private let itemsByID: [FileItem.ID: FileItem]
    private let orderedItems: [FileItem]
    private let locationIDs: [FileItem.ID]
    private let favoriteIDs: [FileItem.ID]
    private let capacities: [VolumeID: Int64]

    /// Creates a tree from its items. Items without a parent, or in This
    /// Mac, are the locations, in the order given.
    ///
    /// Precondition: identities are unique, every `parentID` and every
    /// favorite is one of the items.
    public init(
        _ items: [FileItem], favorites: [FileItem.ID] = [], capacities: [VolumeID: Int64] = [:]
    ) {
        let byID = Dictionary(items.map { ($0.id, $0) }) { first, _ in first }
        precondition(byID.count == items.count, "identities are unique")
        precondition(
            items.allSatisfy { item in
                item.parentID.map { byID[$0] != nil || $0 == .computer } ?? true
            },
            "every parentID is one of the items")
        precondition(favorites.allSatisfy { byID[$0] != nil }, "every favorite is one of the items")
        itemsByID = byID
        orderedItems = items
        locationIDs = items.filter { $0.parentID == nil || $0.parentID == .computer }.map(\.id)
        favoriteIDs = favorites
        self.capacities = capacities
    }

    /// Returns the tree without an item and everything inside it.
    public func removing(_ id: FileItem.ID) -> InMemoryFileSystem {
        let removed = Set(itemsByID.keys.filter { $0 == id || ancestry($0).contains(id) })
        return InMemoryFileSystem(
            orderedItems.filter { !removed.contains($0.id) },
            favorites: favoriteIDs.filter { !removed.contains($0) }, capacities: capacities)
    }

    /// Returns the tree with one more item.
    ///
    /// Precondition: its parent exists and its identity is new.
    public func adding(_ item: FileItem) -> InMemoryFileSystem {
        InMemoryFileSystem(orderedItems + [item], favorites: favoriteIDs, capacities: capacities)
    }

    /// Returns the tree with items replaced by new versions with the same identity.
    func replacing(_ changed: [FileItem]) -> InMemoryFileSystem {
        let byID = Dictionary(changed.map { ($0.id, $0) }) { _, last in last }
        return InMemoryFileSystem(
            orderedItems.map { byID[$0.id] ?? $0 }, favorites: favoriteIDs, capacities: capacities)
    }

    /// An item and everything inside it, every folder before what it holds.
    func subtree(_ id: FileItem.ID) -> [FileItem] {
        orderedItems.filter { $0.id == id || ancestry($0.id).contains(id) }
            .map { (item: $0, depth: ancestry($0.id).count) }
            .sorted { $0.depth < $1.depth }
            .map(\.item)
    }

    /// All items, in no particular order.
    public var items: [FileItem] { Array(itemsByID.values) }

    /// The item with an identity, or `nil`.
    public subscript(id: FileItem.ID) -> FileItem? { itemsByID[id] }

    /// The identities of an item's containers, nearest first; empty for an
    /// unknown item. The synchronous form of `ancestorIDs(of:)`, for rules that
    /// take an `ancestry` function.
    public func ancestry(_ id: FileItem.ID) -> [FileItem.ID] {
        var ancestors: [FileItem.ID] = []
        var next = itemsByID[id]?.parentID
        while let parent = next {
            ancestors.append(parent)
            next = itemsByID[parent]?.parentID
        }
        return ancestors
    }

    public func contents(of folder: FileItem.ID) async throws -> [FileItem] {
        if folder == .computer { return try await locations() }
        guard itemsByID[folder] != nil else { throw FileSystemError.notFound(folder) }
        return itemsByID.values.filter { $0.parentID == folder }
    }

    public func item(at id: FileItem.ID) async throws -> FileItem {
        if id == .computer { return .computer() }
        guard let item = itemsByID[id] else { throw FileSystemError.notFound(id) }
        return item
    }

    public func locations() async throws -> [FileItem] {
        locationIDs.compactMap { itemsByID[$0] }
    }

    public func favorites() async throws -> [FileItem] {
        favoriteIDs.compactMap { itemsByID[$0] }
    }

    public func availableCapacity(of folder: FileItem.ID) async throws -> Int64? {
        if folder == .computer { return nil }
        guard let item = itemsByID[folder] else { throw FileSystemError.notFound(folder) }
        return capacities[item.volume]
    }
}
