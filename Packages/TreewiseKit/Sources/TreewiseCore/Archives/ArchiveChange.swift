/// A change to what an archive holds, in paths inside the archive (ADR 0078).
public enum ArchiveChange: Hashable, Sendable {
    /// These paths are added, or replaced when they exist, each a file or folder.
    case add([String])
    /// These paths go, with everything below them.
    case remove([String])
    /// A file or folder goes to another path, with everything below it.
    case relocate(from: String, to: String)
}

extension ArchiveTree {
    /// The paths the archive should hold after `change`, to check the new
    /// archive by. A folder only its contents named goes when they are gone.
    public func paths(after change: ArchiveChange) -> Set<String> {
        var result = paths
        switch change {
        case .add(let added):
            for path in added { result.formUnion(Self.withFolders(path)) }
        case .remove(let removed):
            for path in removed { result = result.filter { !Self.isAtOrBelow($0, path) } }
        case .relocate(let source, let target):
            let moved = result.filter { Self.isAtOrBelow($0, source) }
            result.subtract(moved)
            for path in moved {
                result.formUnion(Self.withFolders(target + path.dropFirst(source.count)))
            }
        }
        return withoutEmptiedImplicitFolders(result)
    }

    /// Whether this tree holds exactly `expected`, by Swift's comparison of
    /// strings, which treats the Unicode forms of a name as equal.
    public func holdsExactly(_ expected: Set<String>) -> Bool {
        paths == expected
    }

    private func withoutEmptiedImplicitFolders(_ all: Set<String>) -> Set<String> {
        var result = all
        var changed = true
        while changed {
            changed = false
            for path in result where node(at: path)?.entry == nil && node(at: path) != nil {
                let hasChild = result.contains { $0.hasPrefix(path + "/") }
                if !hasChild {
                    result.remove(path)
                    changed = true
                }
            }
        }
        return result
    }

    private static func isAtOrBelow(_ path: String, _ folder: String) -> Bool {
        path == folder || path.hasPrefix(folder + "/")
    }

    /// A path and the folders it is in.
    private static func withFolders(_ path: String) -> Set<String> {
        var result: Set<String> = []
        var current = ""
        for part in path.split(separator: "/") {
            current = current.isEmpty ? String(part) : current + "/" + part
            result.insert(current)
        }
        return result
    }
}
