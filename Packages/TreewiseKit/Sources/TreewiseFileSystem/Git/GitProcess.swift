#if os(macOS)
    import Foundation
    import Synchronization
    import TreewiseCore

    /// Runs git as a child process: at a fixed path, with arguments as an array and
    /// without a shell, off the main thread (ADR 0149).
    enum GitProcess {
        /// What git is told besides the user's own environment: take no lock it can do
        /// without, so reading the state never writes `.git/index` and wakes its own
        /// watching; never ask for a password; write its messages in English.
        private static let overrides = [
            "GIT_OPTIONAL_LOCKS": "0", "GIT_TERMINAL_PROMPT": "0", "LC_ALL": "C",
        ]
        /// Variables that would point git at another repository than the folder's.
        private static let removed = ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"]
        /// What has to end before a run is over: git's output, its complaints and git.
        private static let endings = 3

        /// Runs git in `folder` and returns what it wrote.
        ///
        /// - Throws: `FileSystemError.unexpected` with git's complaint when it fails.
        static func run(_ tool: GitTool, in folder: String, _ arguments: [String]) async throws
            -> Data
        {
            var data = Data()
            for try await part in stream(tool, in: folder, arguments) { data.append(part) }
            return data
        }

        /// Runs git in `folder` and yields what it writes as it comes, so a long output,
        /// such as a history, can be read while git goes on. Ending the iteration stops git.
        ///
        /// Both pipes are read as data arrives, so neither fills up while git waits on it,
        /// and no thread waits on git. The stream throws `FileSystemError.unexpected` with
        /// git's complaint when it fails.
        static func stream(_ tool: GitTool, in folder: String, _ arguments: [String])
            -> AsyncThrowingStream<Data, any Error>
        {
            AsyncThrowingStream { continuation in
                let output = Pipe()
                let errors = Pipe()
                let process = makeProcess(
                    tool, in: folder, arguments, output: output, errors: errors)
                let complaint = Mutex(Data())
                let ended = DispatchGroup()
                for _ in 0..<endings { ended.enter() }
                read(output, until: ended) { continuation.yield($0) }
                read(errors, until: ended) { part in complaint.withLock { $0.append(part) } }
                process.terminationHandler = { _ in ended.leave() }
                do {
                    try process.run()
                } catch {
                    output.fileHandleForReading.readabilityHandler = nil
                    errors.fileHandleForReading.readabilityHandler = nil
                    continuation.finish(
                        throwing: FileSystemError.unexpected(error.localizedDescription))
                    return
                }
                continuation.onTermination = { _ in
                    if process.isRunning { process.terminate() }
                }
                ended.notify(queue: .global(qos: .utility)) {
                    finish(continuation, after: process, complaint: complaint)
                }
            }
        }

        /// Hands each part `pipe` brings to `take` as it arrives, and leaves `ended` when
        /// git closes it.
        private static func read(
            _ pipe: Pipe, until ended: DispatchGroup, take: @escaping @Sendable (Data) -> Void
        ) {
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let part = handle.availableData
                if part.isEmpty {
                    handle.readabilityHandler = nil
                    ended.leave()
                } else {
                    take(part)
                }
            }
        }

        /// Ends the stream once git has ended: with git's complaint when it failed.
        private static func finish(
            _ continuation: AsyncThrowingStream<Data, any Error>.Continuation,
            after process: Process, complaint: borrowing Mutex<Data>
        ) {
            guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                let text = complaint.withLock { String(bytes: $0, encoding: .utf8) } ?? ""
                continuation.finish(
                    throwing: FileSystemError.unexpected(
                        text.trimmingCharacters(in: .whitespacesAndNewlines)))
                return
            }
            continuation.finish()
        }

        private static func makeProcess(
            _ tool: GitTool, in folder: String, _ arguments: [String], output: Pipe, errors: Pipe
        ) -> Process {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool.executable)
            process.arguments = ["-C", folder] + arguments
            var environment = ProcessInfo.processInfo.environment
            for name in removed { environment[name] = nil }
            process.environment = environment.merging(overrides) { _, new in new }
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = output
            process.standardError = errors
            return process
        }
    }
#endif
