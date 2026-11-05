import Foundation

/// The kernel's table of mounted volumes, the source of This Mac (ADR 0046).
/// The kernel updates it before it reports a change, unlike `/Volumes`, which
/// changes before a volume is mounted, and `mountedVolumeURLs`, which can lag
/// behind an eject. iOS has no volumes to list: there the table is empty and
/// reports no change.
public enum MountTable {
    /// The mount-table events that report a change of the mounted volumes.
    #if os(macOS)
        private static let volumeEvents = UInt32(VQ_MOUNT | VQ_UNMOUNT | VQ_UPDATE)
    #endif

    /// The mount points of the mounted volumes, the startup volume first,
    /// then in the kernel's order.
    ///
    /// - Parameter includingHidden: whether to list the volumes macOS keeps
    ///   out of Finder's sidebar (`MNT_DONTBROWSE`), such as its system volumes.
    public static func mountPoints(includingHidden: Bool = false) -> [URL] {
        #if os(macOS)
            var entries: UnsafeMutablePointer<statfs>?
            let count = Int(getmntinfo_r_np(&entries, MNT_NOWAIT))
            guard let entries else { return [] }
            defer { free(entries) }
            let paths = (0..<count).compactMap { index -> String? in
                let entry = entries[index]
                let isHidden = entry.f_flags & UInt32(MNT_DONTBROWSE) != 0
                return isHidden && !includingHidden ? nil : path(of: entry)
            }
            let startup = paths.filter { $0 == "/" }
            return (startup + paths.filter { $0 != "/" }).map { URL(fileURLWithPath: $0) }
        #else
            return []
        #endif
    }

    /// Reports each change of the mounted volumes: one mounted, unmounted or
    /// renamed. A change reported means `mountPoints()` already shows it.
    /// The stream never ends by itself; it stops watching when its consumer stops.
    public static func changes() -> AsyncStream<Void> {
        #if os(macOS)
            AsyncStream { continuation in
                let queue = kqueue()
                var filter = kevent(
                    ident: 0, filter: Int16(EVFILT_FS), flags: UInt16(EV_ADD | EV_CLEAR),
                    fflags: 0, data: 0, udata: nil)
                guard queue >= 0, kevent(queue, &filter, 1, nil, 0, nil) == 0 else {
                    if queue >= 0 { close(queue) }
                    continuation.finish()
                    return
                }
                // A kqueue is readable while it holds events, so a read source
                // wakes up for them without a thread blocked in kevent.
                let source = DispatchSource.makeReadSource(
                    fileDescriptor: queue, queue: DispatchQueue(label: "Treewise.MountTable"))
                source.setEventHandler {
                    if drain(queue) & volumeEvents != 0 { continuation.yield() }
                }
                source.setCancelHandler { close(queue) }
                continuation.onTermination = { _ in source.cancel() }
                source.resume()
            }
        #else
            AsyncStream { $0.finish() }
        #endif
    }

    #if os(macOS)
        /// Takes every pending event off `queue` without waiting, and returns
        /// their flags combined.
        private static func drain(_ queue: Int32) -> UInt32 {
            var flags: UInt32 = 0
            var event = kevent()
            var noWait = timespec()
            while kevent(queue, nil, 0, &event, 1, &noWait) > 0 {
                flags |= event.fflags
            }
            return flags
        }

        /// The mount point of a table entry, if it is valid UTF-8.
        private static func path(of entry: statfs) -> String? {
            withUnsafeBytes(of: entry.f_mntonname) { bytes in
                String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8)
            }
        }
    #endif
}
