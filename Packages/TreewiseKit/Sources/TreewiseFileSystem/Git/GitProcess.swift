#if os(macOS)
    import Foundation
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

        /// Runs git in `folder` and returns what it wrote.
        ///
        /// - Throws: `FileSystemError.unexpected` with git's complaint when it fails.
        static func run(_ tool: GitTool, in folder: String, _ arguments: [String]) async throws
            -> Data
        {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    continuation.resume(
                        with: Result { try runNow(tool, in: folder, arguments) })
                }
            }
        }

        private static func runNow(_ tool: GitTool, in folder: String, _ arguments: [String])
            throws -> Data
        {
            let output = Pipe()
            let errors = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool.executable)
            process.arguments = ["-C", folder] + arguments
            var environment = ProcessInfo.processInfo.environment
            for name in removed { environment[name] = nil }
            process.environment = environment.merging(overrides) { _, new in new }
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = output
            process.standardError = errors
            do {
                try process.run()
            } catch {
                throw FileSystemError.unexpected(error.localizedDescription)
            }
            // Both pipes are read at once, so neither fills up while git waits on it.
            var complaint = Data()
            let readErrors = DispatchWorkItem {
                complaint = errors.fileHandleForReading.readDataToEndOfFile()
            }
            DispatchQueue.global(qos: .utility).async(execute: readErrors)
            let data = output.fileHandleForReading.readDataToEndOfFile()
            readErrors.wait()
            process.waitUntilExit()
            guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                throw FileSystemError.unexpected(
                    (String(bytes: complaint, encoding: .utf8) ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return data
        }
    }
#endif
