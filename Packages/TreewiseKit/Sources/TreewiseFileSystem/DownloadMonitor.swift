#if os(macOS)
    import Foundation
    import Synchronization
    import TreewiseCore

    /// Follows the downloads of files kept only online, through the progress a
    /// cloud service publishes for a file (ADR 0051). It only listens: it starts
    /// no download.
    public struct DownloadMonitor: Sendable {
        /// How many files are followed at once; a folder with more shows the cloud
        /// without a ring for the rest.
        public static let maximumFiles = 1000

        /// The downloads running and their fractions done, kept up to date.
        private final class Downloads: Sendable {
            private let running = Mutex<[FileItem.ID: Double]>([:])
            private let continuation: AsyncStream<[FileItem.ID: Double]>.Continuation

            init(continuation: AsyncStream<[FileItem.ID: Double]>.Continuation) {
                self.continuation = continuation
            }

            func set(_ fraction: Double?, for file: FileItem.ID) {
                let snapshot = running.withLock {
                    $0[file] = fraction
                    return $0
                }
                continuation.yield(snapshot)
            }
        }

        /// Creates a monitor.
        public init() {}

        /// Reports the downloads running among `files`, at every change, with
        /// each one's fraction done; a download that ends leaves the report.
        /// Postcondition: following stops when the stream is dropped or cancelled.
        public func downloads(of files: [FileItem.ID]) -> AsyncStream<[FileItem.ID: Double]> {
            AsyncStream { continuation in
                let downloads = Downloads(continuation: continuation)
                // Only handed back to `removeSubscriber`, which any thread may call.
                nonisolated(unsafe) let subscribers = files.prefix(Self.maximumFiles).map { file in
                    Progress.addSubscriber(
                        forFileURL: URL(fileURLWithPath: file.rawValue)
                    ) { progress in
                        downloads.set(progress.fractionCompleted, for: file)
                        let observation = progress.observe(\.fractionCompleted) { progress, _ in
                            downloads.set(progress.fractionCompleted, for: file)
                        }
                        return {
                            observation.invalidate()
                            downloads.set(nil, for: file)
                        }
                    }
                }
                continuation.onTermination = { _ in
                    subscribers.forEach(Progress.removeSubscriber)
                }
            }
        }
    }
#endif
