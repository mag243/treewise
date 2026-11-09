#if os(macOS)
    import Foundation
    import TreewiseCore

    /// Runs the system's `tar` as a child process (ADR 0074): at a fixed path,
    /// with arguments as an array and without a shell. `-P` is never passed, so
    /// tar refuses `..` in a path and writing through a symbolic link.
    enum TarProcess {
        /// What a finished run came to.
        struct Outcome {
            /// Whether tar exited without an error.
            var succeeded: Bool
            /// tar's complaints, in the order it made them, up to `maximumFailures`.
            var failures: [String]
        }

        /// Without an explicit UTF-8 locale tar mangles the names of entries:
        /// an app started from the Dock has no `LANG`.
        private static let locale = "en_US.UTF-8"
        private static let executable = "/usr/bin/tar"
        private static let pollInterval = DispatchTimeInterval.milliseconds(20)
        private static let readSize = 16_384
        private static let maximumFailures = 50
        private static let newline = UInt8(ascii: "\n")

        /// Runs tar and waits for it, passing every line it writes to `onLine`.
        /// `temporaryFolder` holds tar's temporary files, which a 7z needs.
        ///
        /// - Throws: `FileSystemError.cancelled` when `control` stopped the run.
        static func run(
            _ arguments: [String], temporaryFolder: URL, control: TransferControl,
            onLine: (String) -> Void
        ) throws -> Outcome {
            guard !control.isStopped else { throw FileSystemError.cancelled }
            let output = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = ["LC_ALL": locale, "TMPDIR": temporaryFolder.path]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = output
            process.standardError = output
            do {
                try process.run()
            } catch {
                throw FileSystemError.unexpected(error.localizedDescription)
            }
            let finished = DispatchSemaphore(value: 0)
            let processID = process.processIdentifier
            DispatchQueue.global(qos: .userInitiated).async {
                follow(control, processID: processID, until: finished)
            }
            let failures = read(output.fileHandleForReading, onLine: onLine)
            process.waitUntilExit()
            finished.signal()
            guard !control.isStopped else { throw FileSystemError.cancelled }
            return Outcome(
                succeeded: process.terminationReason == .exit && process.terminationStatus == 0,
                failures: failures)
        }

        /// Whether a line of tar's output is a complaint rather than an entry.
        static func isFailure(_ line: String) -> Bool {
            line.hasPrefix("tar: ") || (isEntry(line) && line.contains(": "))
        }

        /// Whether a line reports an entry extracted or added (`-v`).
        static func isEntry(_ line: String) -> Bool {
            line.hasPrefix("x ") || line.hasPrefix("a ")
        }

        /// The path in an entry line (`x Photos/empty/`), without its slash.
        static func entryName(_ line: String) -> String {
            let path = line.dropFirst(2)
            return String(path.hasSuffix("/") ? path.dropLast() : path)
        }

        /// Applies pause and stop to the running tar. A stop also continues a
        /// paused tar, which could not act on the terminate signal otherwise.
        private static func follow(
            _ control: TransferControl, processID: pid_t, until finished: DispatchSemaphore
        ) {
            var paused = false
            repeat {
                if control.isStopped {
                    kill(processID, SIGTERM)
                    kill(processID, SIGCONT)
                    return
                }
                if control.isPaused != paused {
                    paused.toggle()
                    kill(processID, paused ? SIGSTOP : SIGCONT)
                }
            } while finished.wait(timeout: .now() + pollInterval) == .timedOut
        }

        /// Reads to the end of tar's output.
        ///
        /// - Returns: the complaints among the lines.
        private static func read(_ handle: FileHandle, onLine: (String) -> Void) -> [String] {
            var buffer = Data()
            var failures: [String] = []
            func deliver(_ bytes: Data) {
                let line = String(bytes: bytes, encoding: .utf8) ?? ""
                if isFailure(line), failures.count < maximumFailures { failures.append(line) }
                onLine(line)
            }
            while let chunk = try? handle.read(upToCount: readSize), !chunk.isEmpty {
                buffer.append(chunk)
                while let end = buffer.firstIndex(of: newline) {
                    deliver(buffer[buffer.startIndex..<end])
                    buffer.removeSubrange(buffer.startIndex...end)
                }
            }
            if !buffer.isEmpty { deliver(buffer) }
            return failures
        }
    }
#endif
