#if os(macOS)
    import CoreServices
    import Foundation

    /// An FSEvents stream that reports the files directly in a folder changing,
    /// which a `DispatchSource` on the folder does not hear (ADR 0051).
    enum FileEvents {
        /// How long the system gathers events into one report, in seconds.
        private static let latency: CFTimeInterval = 0.3

        /// What the stream's C callback needs, reached through its `info` pointer.
        private final class Target: Sendable {
            let folder: String
            let onChange: @Sendable () -> Void

            init(folder: String, onChange: @escaping @Sendable () -> Void) {
                self.folder = folder
                self.onChange = onChange
            }
        }

        /// Starts watching `folder`; the result stops it. `nil` when the folder
        /// is gone or the stream cannot be made.
        static func watch(
            folder: String, onChange: @escaping @Sendable () -> Void
        ) -> (@Sendable () -> Void)? {
            // FSEvents reports real paths, such as /private/var for /var.
            guard let resolved = realpath(folder, nil) else { return nil }
            defer { free(resolved) }
            let target = Target(folder: String(cString: resolved), onChange: onChange)
            var context = FSEventStreamContext(
                version: 0, info: Unmanaged.passUnretained(target).toOpaque(), retain: nil,
                release: nil, copyDescription: nil)
            let flags = FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
            guard
                let created = FSEventStreamCreate(
                    nil, callback, &context, [target.folder] as CFArray,
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
            return {
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
            let isDirectEntry = (0..<count).contains { index in
                let path = String(cString: list[index])
                return (path as NSString).deletingLastPathComponent == target.folder
            }
            if isDirectEntry { target.onChange() }
        }
    }
#endif
