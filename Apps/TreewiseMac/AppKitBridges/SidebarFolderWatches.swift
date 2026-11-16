import Synchronization

/// The watching of the folders open in the sidebar tree, by row (ADR 0112). Every watch
/// stops when it is ended or when this goes, with its window's sidebar.
final class SidebarFolderWatches: Sendable {
    private let tasks = Mutex<[ObjectIdentifier: Task<Void, Never>]>([:])

    /// Whether the row is watched.
    func watches(_ row: ObjectIdentifier) -> Bool {
        tasks.withLock { $0[row] != nil }
    }

    /// Keeps `task` as the row's watch.
    func add(_ task: Task<Void, Never>, for row: ObjectIdentifier) {
        tasks.withLock { tasks in
            tasks[row]?.cancel()
            tasks[row] = task
        }
    }

    /// Stops watching the rows.
    func end(_ rows: [ObjectIdentifier]) {
        tasks.withLock { tasks in
            for row in rows { tasks.removeValue(forKey: row)?.cancel() }
        }
    }

    /// Stops every watch.
    func endAll() {
        tasks.withLock { tasks in
            for task in tasks.values { task.cancel() }
            tasks = [:]
        }
    }

    deinit {
        endAll()
    }
}
