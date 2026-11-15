/// A source of file system items: the local file system, or an in-memory tree
/// for tests and previews.
public protocol FileSystemProviding: Sendable {
    /// Returns the items directly inside a container, in no particular order.
    ///
    /// Precondition: `folder` identifies a container.
    /// - Throws: `FileSystemError.notFound` when `folder` does not exist.
    func contents(of folder: FileItem.ID) async throws -> [FileItem]

    /// Returns the item with an identity.
    ///
    /// - Throws: `FileSystemError.notFound` when no such item exists.
    func item(at id: FileItem.ID) async throws -> FileItem

    /// Returns the sidebar's Locations: mounted volumes and cloud locations,
    /// in the order the sidebar shows them.
    func locations() async throws -> [FileItem]

    /// Returns the sidebar's Favorites, in the order the sidebar shows them.
    func favorites() async throws -> [FileItem]

    /// Returns the free space, in bytes, of the volume a folder is on, or `nil`
    /// when the provider cannot tell.
    ///
    /// - Throws: `FileSystemError.notFound` when `folder` does not exist.
    func availableCapacity(of folder: FileItem.ID) async throws -> Int64?

    /// Whether a folder can be read without a cost worth avoiding, such as a folder on a
    /// local disk; not one in the cloud, on a network volume or inside an archive, where a
    /// reading the user did not ask for may be slow or start work (ADR 0108).
    func readsQuickly(_ folder: FileItem.ID) -> Bool
}

extension FileSystemProviding {
    /// No folder reads quickly unless a provider says so.
    public func readsQuickly(_ folder: FileItem.ID) -> Bool { false }

    /// Returns the identities of an item's containers, nearest first, up to and
    /// including its top-level location.
    ///
    /// Postcondition: the result does not contain `id` itself.
    /// - Throws: `FileSystemError.notFound` when `id` or one of its containers
    ///   does not exist.
    public func ancestorIDs(of id: FileItem.ID) async throws -> [FileItem.ID] {
        var ancestors: [FileItem.ID] = []
        var next = try await item(at: id).parentID
        while let parent = next {
            ancestors.append(parent)
            next = try await item(at: parent).parentID
        }
        return ancestors
    }
}
