#if os(macOS)
    import Foundation
    import Synchronization
    import TreewiseCore

    /// Keeps the listings of archives, each for as long as its archive has the
    /// same size and date, so going through its folders reads nothing again
    /// (ADR 0076).
    final class ArchiveCatalog: Sendable {
        private static let maximumListings = 16

        private struct Listing {
            var signature: ArchiveSignature
            var tree: ArchiveTree
            var lastUse: Int
        }

        private struct Reading {
            var signature: ArchiveSignature
            var task: Task<ArchiveTree, any Error>
        }

        private struct State {
            var listings: [FileItem.ID: Listing] = [:]
            var readings: [FileItem.ID: Reading] = [:]
            var clock = 0
        }

        private let state = Mutex(State())

        /// The listing of an archive, read when it is not known yet. Callers
        /// that ask at the same time share one reading.
        ///
        /// - Throws: `FileSystemError.notFound` when the archive is gone.
        func tree(of archive: FileItem.ID) async throws -> ArchiveTree {
            guard let signature = ArchiveSignature(path: archive.rawValue) else {
                throw FileSystemError.notFound(archive)
            }
            let known = state.withLock { state -> Result<ArchiveTree, Never>? in
                remembered(of: archive, signature, in: &state).map { .success($0) }
            }
            if case .success(let tree) = known { return tree }
            return try await reading(of: archive, signature).value
        }

        /// The listing of an archive when it is already known and current.
        func currentTree(of archive: FileItem.ID) -> ArchiveTree? {
            guard let signature = ArchiveSignature(path: archive.rawValue) else { return nil }
            return state.withLock { remembered(of: archive, signature, in: &$0) }
        }

        /// Stops a listing nobody waits for any more; a caller still waiting
        /// gets `FileSystemError.cancelled`.
        func stopReading(of archive: FileItem.ID) {
            state.withLock { $0.readings.removeValue(forKey: archive)?.task.cancel() }
        }

        private func remembered(
            of archive: FileItem.ID, _ signature: ArchiveSignature, in state: inout State
        ) -> ArchiveTree? {
            guard var listing = state.listings[archive], listing.signature == signature else {
                return nil
            }
            state.clock += 1
            listing.lastUse = state.clock
            state.listings[archive] = listing
            return listing.tree
        }

        private func reading(
            of archive: FileItem.ID, _ signature: ArchiveSignature
        ) -> Task<ArchiveTree, any Error> {
            state.withLock { state in
                if let reading = state.readings[archive], reading.signature == signature {
                    return reading.task
                }
                let task = Task.detached(priority: .userInitiated) { [self] in
                    defer { finishReading(of: archive, signature) }
                    let tree = try await Self.list(archive)
                    keep(tree, of: archive, signature)
                    return tree
                }
                state.readings[archive] = Reading(signature: signature, task: task)
                return task
            }
        }

        private func finishReading(of archive: FileItem.ID, _ signature: ArchiveSignature) {
            state.withLock { state in
                if state.readings[archive]?.signature == signature {
                    state.readings[archive] = nil
                }
            }
        }

        private func keep(
            _ tree: ArchiveTree, of archive: FileItem.ID, _ signature: ArchiveSignature
        ) {
            state.withLock { state in
                state.clock += 1
                state.listings[archive] = Listing(
                    signature: signature, tree: tree, lastUse: state.clock)
                if state.listings.count > Self.maximumListings,
                    let oldest = state.listings.min(by: { $0.value.lastUse < $1.value.lastUse })
                {
                    state.listings[oldest.key] = nil
                }
            }
        }

        /// Runs `tar` off Swift's cooperative pool, as it blocks until it ends;
        /// coordinated, so a file kept only online downloads first (ADR 0047).
        private static func list(_ archive: FileItem.ID) async throws -> ArchiveTree {
            let control = TransferControl()
            let url = URL(fileURLWithPath: archive.rawValue)
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        continuation.resume(
                            with: Result {
                                try FileCoordination.read(url) {
                                    try ArchiveLister.tree(of: $0, control: control)
                                }
                            })
                    }
                }
            } onCancel: {
                control.stop()
            }
        }
    }
#endif
