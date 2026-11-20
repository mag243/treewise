import Foundation

/// A template as parts (ADR 0144): the template an element with its name, and each folder
/// of its tree an element of its own, by an id the folder keeps, with its name, the folder
/// it is in (empty for the root) and its name settings. A tree's folders are ordered by
/// name, so a folder has no place to merge.
extension FolderTemplate {
    private enum Part {
        static let name = "name"
        static let parent = "parent"
        static let names = "names"
    }

    /// The template with an id on every folder: at first, when no folder has one, from the
    /// folders' paths, so two devices give a template the same ids; after that a new id for
    /// a folder added.
    public func withFolderIDs() -> FolderTemplate {
        let first = !root.hasAnyID
        return FolderTemplate(
            id: id, name: name, root: root.givingIDs(path: id, derived: first))
    }

    /// The template as elements and their parts.
    public var syncElements: [SyncElement: [String: JSONValue]] {
        var elements: [SyncElement: [String: JSONValue]] = [
            .template(id): [Part.name: .string(name)]
        ]
        func add(_ folder: FolderTree, parent: String) {
            let folderID = folder.id ?? folder.name
            var parts: [String: JSONValue] = [
                Part.name: .string(folder.name), Part.parent: .string(parent),
            ]
            parts[Part.names] = folder.names.flatMap { try? JSONValue(encoding: $0) }
            elements[.templateFolder(template: id, folder: folderID)] = parts
            for inner in folder.folders { add(inner, parent: folderID) }
        }
        add(root, parent: "")
        return elements
    }

    /// The template `syncID` from the records of its elements, nil when it is not there.
    /// A removed folder that holds a folder that is there stays; a folder in a folder no
    /// record names goes under the root, as does the folder of a loop moved last; of two
    /// folders of one name beside each other the later is named `name 2`.
    public init?(syncID: String, records: [SyncElement: [String: SyncRecord]]) {
        guard let parts = records[.template(syncID)].flatMap(SyncParts.values),
            case .string(let name)? = parts[Part.name]
        else { return nil }
        let folders = TemplateFolders(template: syncID, records: records)
        guard let root = folders.tree() else { return nil }
        self.init(id: syncID, name: name, root: root)
    }
}

/// A template's folders as their records make them.
private struct TemplateFolders {
    struct Folder {
        let id: String
        let name: String
        var parent: String
        let names: FolderNameSettings?
        let movedAt: Date
    }

    private var folders: [String: Folder] = [:]
    private var rootID: String?

    init(template: String, records: [SyncElement: [String: SyncRecord]]) {
        var all: [String: (Folder, isThere: Bool)] = [:]
        for (element, parts) in records {
            guard case .templateFolder(let owner, let id) = element, owner == template,
                case .string(let name)? = parts["name"]?.value
            else { continue }
            let parent: String =
                if case .string(let value)? = parts["parent"]?.value { value } else { "" }
            let folder = Folder(
                id: id, name: name, parent: parent,
                names: parts["names"]?.value.decoded(as: FolderNameSettings.self),
                movedAt: parts["parent"]?.changedAt ?? .distantPast)
            all[id] = (folder, SyncParts.values(of: parts) != nil)
        }
        // A removed folder stays while a folder that is there is inside it.
        var there = Set(all.filter(\.value.isThere).keys)
        for id in there {
            var parent = all[id]?.0.parent ?? ""
            while !parent.isEmpty, let above = all[parent], !there.contains(parent) {
                there.insert(parent)
                parent = above.0.parent
            }
        }
        folders = all.filter { there.contains($0.key) }.mapValues(\.0)
        rootID = folders.values.filter(\.parent.isEmpty).map(\.id).min()
        guard let rootID else { return }
        for id in folders.keys where id != rootID && folders[folders[id]?.parent ?? ""] == nil {
            folders[id]?.parent = rootID
        }
        breakLoops(under: rootID)
    }

    /// Puts the folder of each loop that moved last directly under the root.
    private mutating func breakLoops(under rootID: String) {
        for start in folders.keys.sorted() {
            var seen: [String] = []
            var current = start
            while current != rootID, let folder = folders[current] {
                if let loopStart = seen.firstIndex(of: current) {
                    let loop = seen[loopStart...]
                    let last = loop.max {
                        (folders[$0]?.movedAt ?? .distantPast, $0) < (
                            folders[$1]?.movedAt ?? .distantPast, $1
                        )
                    }
                    if let last { folders[last]?.parent = rootID }
                    break
                }
                seen.append(current)
                current = folder.parent.isEmpty ? rootID : folder.parent
            }
        }
    }

    func tree() -> FolderTree? {
        guard let rootID, let root = folders[rootID] else { return nil }
        return tree(of: root)
    }

    private func tree(of folder: Folder) -> FolderTree {
        let inside = folders.values.filter { $0.parent == folder.id && $0.id != rootID }
            .sorted { $0.id < $1.id }
        var taken: Set<String> = []
        let trees = inside.map { inner -> FolderTree in
            var name = inner.name
            var number = 2
            while taken.contains(ConflictResolver.comparisonKey(name)) {
                name = "\(inner.name) \(number)"
                number += 1
            }
            taken.insert(ConflictResolver.comparisonKey(name))
            let made = tree(of: inner)
            return FolderTree(id: made.id, name: name, folders: made.folders, names: made.names)
        }
        return FolderTree(id: folder.id, name: folder.name, folders: trees, names: folder.names)
    }
}

extension FolderTree {
    var hasAnyID: Bool { id != nil || folders.contains(where: \.hasAnyID) }

    /// The tree with an id on each folder: from `path` when `derived`, else new where missing.
    func givingIDs(path: String, derived: Bool) -> FolderTree {
        var seen: [String: Int] = [:]
        let inner = folders.map { folder -> FolderTree in
            let count = (seen[folder.name] ?? 0) + 1
            seen[folder.name] = count
            let below = path + "/" + folder.name + (count > 1 ? "#\(count)" : "")
            return folder.givingIDs(path: below, derived: derived)
        }
        let own = id ?? (derived ? path : UUID().uuidString)
        return FolderTree(id: own, name: name, folders: inner, names: names)
    }
}
