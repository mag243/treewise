#if os(macOS)
    import CoreServices
    import Foundation
    import Synchronization

    /// An FSEvents stream that reports the files directly in a folder changing,
    /// which a `DispatchSource` on the folder does not hear (ADR 0051), or anything in
    /// a git working copy changing (ADR 0149).
    enum FileEvents {
        /// How long the system gathers events into one report, in seconds.
        private static let latency: CFTimeInterval = 0.3

        /// What the stream's C callback needs, reached through its `info` pointer.
        private final class Target: Sendable {
            let accepts: @Sendable (String) -> Bool
            let onChange: @Sendable ([String]) -> Void

            init(
                accepts: @escaping @Sendable (String) -> Bool,
                onChange: @escaping @Sendable ([String]) -> Void
            ) {
                self.accepts = accepts
                self.onChange = onChange
            }
        }

        /// Starts watching the files directly in `folder`; the result stops it. `nil`
        /// when the folder is gone or the stream cannot be made.
        static func watch(
            folder: String, onChange: @escaping @Sendable () -> Void
        ) -> (@Sendable () -> Void)? {
            guard let resolved = realPath(folder) else { return nil }
            return watch(
                trees: [resolved],
                accepts: { ($0 as NSString).deletingLastPathComponent == resolved },
                onChange: { _ in onChange() })
        }

        /// The path with its links resolved, as FSEvents reports it, such as /private/var
        /// for /var; `nil` when it is gone.
        static func realPath(_ path: String) -> String? {
            guard let resolved = realpath(path, nil) else { return nil }
            defer { free(resolved) }
            return String(cString: resolved)
        }

        /// Starts watching everything in the folders `trees`, given as real paths, and
        /// reports the paths of a batch of changes that `accepts`; the result stops it.
        /// `nil` when the stream cannot be made.
        static func watch(
            trees: [String], accepts: @escaping @Sendable (String) -> Bool,
            onChange: @escaping @Sendable ([String]) -> Void
        ) -> (@Sendable () -> Void)? {
            let target = Target(accepts: accepts, onChange: onChange)
            var context = FSEventStreamContext(
                version: 0, info: Unmanaged.passUnretained(target).toOpaque(), retain: nil,
                release: nil, copyDescription: nil)
            let flags = FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
            guard
                let created = FSEventStreamCreate(
                    nil, callback, &context, trees as CFArray,
                    FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags)
            else { return nil }
            // Touched only to stop the stream, on the queue its events arrive on.
            nonisolated(unsafe) let stream = created
            let queue = DispatchQueue(label: "Treewise.FileEvents")
            FSEventStreamSetDispatchQueue(stream, queue)
            guard FSEventStreamStart(stream) else {
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                return nil
            }
            // Stopping twice would release the stream twice; only the first stop counts.
            let stopped = Mutex(false)
            return {
                let isFirst = stopped.withLock { wasStopped in
                    defer { wasStopped = true }
                    return !wasStopped
                }
                guard isFirst else { return }
                queue.async {
                    FSEventStreamStop(stream)
                    FSEventStreamInvalidate(stream)
                    FSEventStreamRelease(stream)
                    // The callback's `info` points at the target until here.
                    withExtendedLifetime(target) {}
                }
            }
        }

        private static let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let target = Unmanaged<Target>.fromOpaque(info).takeUnretainedValue()
            let list = paths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
            let accepted = (0..<count).map { String(cString: list[$0]) }.filter(target.accepts)
            if !accepted.isEmpty { target.onChange(accepted) }
        }
    }
#endif
