import Foundation

/// The folders and files an archive's listing comes to: what extracting it can
/// deliver (ADR 0076).
public struct ArchiveTree: Sendable {
    /// A file or folder in the archive.
    public struct Node: Hashable, Sendable {
        /// The path inside the archive, without a leading or trailing slash.
        public let path: String
        /// The last part of the path.
        public let name: String
        /// Whether the node is a folder.
        public var isFolder: Bool
        /// The entry of the listing, or `nil` for a folder only its contents name.
        public var entry: ArchiveEntry?
    }

    private static let macMetadataFolder = "__MACOSX"
    private static let macMetadataPrefix = "._"

    private var nodes: [String: Node] = [:]
    private var children: [String: [String]] = [:]

    /// Builds the tree. A leading `/` or `./` is removed, and a folder without
    /// its own line is added. An entry with `..`, which `tar` refuses, is left
    /// out, as are `__MACOSX` and `._` entries, which `tar` folds into the file
    /// they belong to. Of the same path twice, the last counts.
    public init(entries: some Sequence<ArchiveEntry>) {
        for entry in entries {
            guard let parts = Self.parts(of: entry.storedName) else { continue }
            insert(entry, parts: parts)
        }
    }

    /// Every path the archive holds, folders included.
    public var paths: Set<String> {
        Set(nodes.keys)
    }

    /// The node at a path inside the archive, or `nil` when there is none.
    public func node(at path: String) -> Node? {
        nodes[path]
    }

    /// The node of a name as the archive stores it, or `nil` when it is not shown.
    public func node(forStoredName storedName: String) -> Node? {
        Self.parts(of: storedName).flatMap { nodes[$0.joined(separator: "/")] }
    }

    /// What a folder holds, or `nil` when `path` is not a folder. The empty
    /// path is the top level.
    public func contents(of path: String) -> [Node]? {
        guard path.isEmpty || nodes[path]?.isFolder == true else { return nil }
        return (children[path] ?? []).compactMap { nodes[$0] }
    }

    /// The bytes at a path: a file's size, or the sum of a folder's files.
    public func byteCount(at path: String) -> Int64 {
        guard path.isEmpty || nodes[path]?.isFolder == true else {
            return nodes[path]?.entry?.size ?? 0
        }
        return (children[path] ?? []).reduce(0) { $0 + byteCount(at: $1) }
    }

    /// The items directly inside a place, or `nil` when it is not a folder.
    public func items(in place: ArchivePath) -> [FileItem]? {
        contents(of: place.entry)?.map { Self.item(of: $0, at: place.child($0.name)) }
    }

    /// The item of a place, or `nil` when the archive has no such path.
    public func item(at place: ArchivePath) -> FileItem? {
        guard !place.isTopLevel else { return Self.topLevelItem(of: place) }
        return nodes[place.entry].map { Self.item(of: $0, at: place) }
    }

    /// The item of an archive's top level, which needs no listing.
    public static func topLevelItem(of place: ArchivePath) -> FileItem {
        FileItem(
            id: place.id, name: place.name, kind: .folder, parentID: place.parent,
            volume: place.volume)
    }

    private static func item(of node: Node, at place: ArchivePath) -> FileItem {
        var item = FileItem(
            id: place.id, name: node.name, kind: node.isFolder ? .folder : .file,
            parentID: place.parent, volume: place.volume, modified: node.entry?.modified,
            size: node.isFolder ? nil : node.entry?.size, isHidden: node.name.hasPrefix("."))
        item.modifiedHasTime = node.entry?.modifiedHasTime ?? true
        return item
    }

    /// The parts of a stored name, or `nil` for one that is no entry to show.
    private static func parts(of storedName: String) -> [String]? {
        let parts = storedName.split(separator: "/").map(String.init).filter { $0 != "." }
        let refused = parts.contains {
            $0 == ".." || $0 == macMetadataFolder || $0.hasPrefix(macMetadataPrefix)
        }
        return parts.isEmpty || refused ? nil : parts
    }

    private mutating func insert(_ entry: ArchiveEntry, parts: [String]) {
        var parent = ""
        for (index, part) in parts.enumerated() {
            let path = parent.isEmpty ? part : parent + "/" + part
            if nodes[path] == nil {
                nodes[path] = Node(path: path, name: part, isFolder: true, entry: nil)
                children[parent, default: []].append(path)
            }
            if index == parts.count - 1 {
                nodes[path]?.entry = entry
                nodes[path]?.isFolder = entry.isFolder || children[path] != nil
            } else {
                nodes[path]?.isFolder = true
            }
            parent = path
        }
    }
}
